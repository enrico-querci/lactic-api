module Catalog
  # Folds duplicate muscle rows onto their canonical key.
  #
  # Extending NormalizeExercise::MUSCLE_ALIASES only changes what a *future*
  # sync writes. Rows already imported under the duplicate key stay where they
  # are, so a filter on Delts keeps missing the exercises tagged Deltoids until
  # the existing data is merged too.
  #
  # Re-syncing would also fix it, but that costs a full walk of the provider
  # catalog — ~133 requests against a monthly quota — to correct something that
  # is purely a local relabelling. This does it with no provider calls at all.
  #
  # Idempotent: once merged there is no duplicate row left to find.
  class MergeMuscleAliases
    Report = Data.define(:merged_muscles, :relinked, :deduplicated, :promoted) do
      def to_s
        "#{merged_muscles} duplicate muscles merged, #{relinked} links re-pointed, " \
          "#{deduplicated} redundant links removed, #{promoted} roles promoted to primary"
      end
    end

    def self.call(...) = new(...).call

    def initialize(aliases: NormalizeExercise::MUSCLE_ALIASES)
      @aliases = aliases
    end

    def call
      merged = relinked = deduplicated = promoted = 0

      @aliases.each do |duplicate_key, canonical_key|
        duplicate = Muscle.find_by(key: duplicate_key)
        next if duplicate.nil?

        canonical = Muscle.find_by(key: canonical_key)

        ActiveRecord::Base.transaction do
          if canonical.nil?
            # Nothing to merge into: the duplicate simply becomes canonical.
            duplicate.update!(key: canonical_key)
          else
            r, d, p = merge(duplicate, canonical)
            relinked += r
            deduplicated += d
            promoted += p
            duplicate.destroy!
          end
          merged += 1
        end
      end

      report = Report.new(
        merged_muscles: merged, relinked: relinked,
        deduplicated: deduplicated, promoted: promoted
      )
      Rails.logger.info("catalog_muscle_merge #{report}")
      report
    end

    private

    def merge(duplicate, canonical)
      relinked = deduplicated = promoted = 0

      ExerciseMuscle.where(muscle_id: duplicate.id).find_each do |link|
        existing = ExerciseMuscle.find_by(exercise_id: link.exercise_id, muscle_id: canonical.id)

        if existing.nil?
          # No canonical link yet: re-point rather than delete and recreate, so
          # the association keeps its id and timestamps.
          link.update_columns(muscle_id: canonical.id)
          relinked += 1
        else
          # The exercise already references the canonical muscle. Keep the
          # stronger role — primary outranks secondary — and drop the duplicate
          # link, because [exercise_id, muscle_id] is unique.
          if link.role == "primary" && existing.role != "primary"
            link.destroy!
            existing.update_columns(role: "primary")
            promoted += 1
          else
            link.destroy!
          end
          deduplicated += 1
        end
      end

      [ relinked, deduplicated, promoted ]
    end
  end
end
