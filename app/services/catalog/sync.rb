module Catalog
  # Pulls a provider catalog into Lactic.
  #
  # Guarantees, in order of how much damage getting them wrong would do:
  #
  #   1. Coach-owned custom exercises are never read, written, or deactivated.
  #      Every query is scoped to `source:` and `is_custom: false`.
  #   2. Lactic exercise ids are stable. Records are matched on
  #      [source, source_uid], so a program referencing an exercise keeps
  #      working across syncs.
  #   3. Nothing is ever hard-deleted. A record the provider stops publishing
  #      is marked inactive, and only after a complete, verified pass.
  #   4. A malformed record is quarantined, not fatal. One bad row must not
  #      cost the other 1,326.
  class Sync
    # A record is only deactivated if the run saw the whole catalog. Without
    # this, a provider outage that returns two records would deactivate
    # everything else.
    class IncompleteCatalog < StandardError; end

    Rejection = Data.define(:source_uid, :reasons)

    def self.call(...) = new(...).call

    def initialize(provider:, now: -> { Time.current })
      @provider = provider
      @now = now
      @seen_uids = []
      @rejections = []
      @created = 0
      @updated = 0
      @unchanged = 0
    end

    def call
      run = CatalogSyncRun.create!(source: @provider.source, status: "running", started_at: @now.call)

      begin
        expected_total = @provider.total_count
        @provider.each_record { |raw| ingest(raw) }
        deactivated = reconcile(expected_total)

        run.update!(
          fetched_count: @seen_uids.size + @rejections.size,
          created_count: @created,
          updated_count: @updated,
          deactivated_count: deactivated,
          rejected_count: @rejections.size,
          error_summary: rejection_summary
        )
        run.finish!(status: "succeeded", error_summary: rejection_summary)
      rescue StandardError => e
        run.update!(
          fetched_count: @seen_uids.size + @rejections.size,
          created_count: @created,
          updated_count: @updated,
          rejected_count: @rejections.size
        )
        # Only the class and message are recorded. Provider error messages are
        # written to never contain a key, a URL, or a response body.
        run.finish!(status: "failed", error_summary: "#{e.class}: #{e.message}")
        raise
      end

      run
    end

    private

    def ingest(raw)
      normalized = NormalizeExercise.call(raw)

      unless normalized.valid?
        @rejections << Rejection.new(source_uid: normalized.source_uid, reasons: normalized.errors)
        return
      end

      # One transaction per record: a failure quarantines that record only,
      # leaving everything already imported intact.
      ActiveRecord::Base.transaction(requires_new: true) do
        exercise = upsert_exercise(normalized)
        upsert_translation(exercise, normalized)
        upsert_muscles(exercise, normalized)
        upsert_equipment(exercise, normalized)
        upsert_animation(exercise, normalized)
      end

      @seen_uids << normalized.source_uid
    rescue ActiveRecord::ActiveRecordError => e
      @rejections << Rejection.new(source_uid: normalized&.source_uid, reasons: [ e.class.name ])
    end

    def upsert_exercise(normalized)
      exercise = Exercise.find_or_initialize_by(
        source: @provider.source,
        source_uid: normalized.source_uid,
        is_custom: false
      )
      was_new = exercise.new_record?

      exercise.assign_attributes(
        # `name` and `muscle_group` are the pre-catalog flat columns. They are
        # still NOT NULL and still power the current API, so the importer has
        # to keep them populated until Stage 5 moves the contract onto
        # translations and muscles.
        name: normalized.name,
        muscle_group: normalized.primary_muscle.name,
        category: normalized.category,
        difficulty: normalized.difficulty,
        mechanic: normalized.mechanic,
        force: normalized.force,
        assignable: normalized.assignable?,
        active: true,
        content_checksum: normalized.content_checksum
      )

      if was_new || exercise.changed?
        exercise.last_synced_at = @now.call
        exercise.save!
        was_new ? @created += 1 : @updated += 1
      else
        # Nothing about this exercise changed, so record only that it was seen.
        # Assigning last_synced_at and saving would mark the row dirty and bump
        # updated_at on all ~1,300 records every single sync, which would make
        # updated_at useless as a signal that content actually changed.
        exercise.update_columns(last_synced_at: @now.call)
        @unchanged += 1
      end

      exercise
    end

    # English comes from the provider. A human-edited English translation is
    # left alone, the same protection Stage 3 relies on for Italian.
    def upsert_translation(exercise, normalized)
      translation = exercise.exercise_translations.find_or_initialize_by(locale: "en")
      return if translation.persisted? && !translation.overwritable_by_sync?

      translation.update!(
        name: normalized.name,
        description: normalized.description,
        instructions: normalized.instructions,
        translation_source: "provider",
        source_checksum: normalized.content_checksum
      )
    end

    # Compare, then replace wholesale if anything differs.
    #
    # Incremental reconciliation is not worth it here: only one row per
    # exercise may be `primary`, enforced by a partial unique index, so any
    # incremental path has to get delete-before-insert ordering right in every
    # combination of promotion, demotion and swap. Replacing the whole set
    # inside the record's transaction is provably correct, and the comparison
    # means an unchanged exercise still costs no writes.
    def upsert_muscles(exercise, normalized)
      desired = { normalized.primary_muscle.key => "primary" }
      normalized.secondary_muscles.each { |muscle| desired[muscle.key] ||= "secondary" }

      records = ([ normalized.primary_muscle ] + normalized.secondary_muscles)
        .uniq(&:key)
        .to_h { |muscle| [ muscle.key, resolve_muscle(muscle) ] }

      target = desired.to_h { |key, role| [ records.fetch(key).id, role ] }
      current = exercise.exercise_muscles.to_h { |link| [ link.muscle_id, link.role ] }
      return if target == current

      exercise.exercise_muscles.destroy_all
      target.each { |muscle_id, role| exercise.exercise_muscles.create!(muscle_id: muscle_id, role: role) }
    end

    # Muscles arrive from two different provider vocabularies: `target` is a
    # closed list, `secondaryMuscles` is open, so an unknown muscle is created
    # rather than rejected. A blank region is filled in when live data supplies
    # one, which corrects the two regions the seed file had to infer.
    def resolve_muscle(normalized_muscle)
      muscle = Muscle.find_or_initialize_by(key: normalized_muscle.key)
      muscle.name = normalized_muscle.name if muscle.name.blank?
      muscle.region = normalized_muscle.region if muscle.region.blank? && normalized_muscle.region.present?
      muscle.save! if muscle.changed?
      muscle
    end

    def upsert_equipment(exercise, normalized)
      records = normalized.equipment.map do |item|
        equipment = Equipment.find_or_initialize_by(key: item.key)
        equipment.name = item.name if equipment.name.blank?
        equipment.save! if equipment.changed?
        equipment
      end

      target = records.map(&:id).to_set
      current = exercise.exercise_equipment.map(&:equipment_id).to_set
      return if target == current

      exercise.exercise_equipment.destroy_all
      target.each { |equipment_id| exercise.exercise_equipment.create!(equipment_id: equipment_id) }
    end

    def upsert_animation(exercise, normalized)
      return if normalized.animation.nil?

      medium = exercise.exercise_media.find_or_initialize_by(kind: "animation", position: 1)
      medium.update!(
        mime_type: normalized.animation.mime_type,
        provider_url: normalized.animation.provider_url,
        provider_media_uid: normalized.animation.provider_media_uid
      )
    end

    # Deactivation is the one destructive-looking step, so it only runs when
    # the pass is demonstrably complete. A provider returning a short catalog
    # must not silently retire the rest.
    def reconcile(expected_total)
      return 0 if @seen_uids.empty?

      if expected_total.is_a?(Integer)
        accounted = @seen_uids.size + @rejections.size
        if accounted < expected_total
          raise IncompleteCatalog,
            "saw #{accounted} of #{expected_total} records; refusing to deactivate"
        end
      end

      Exercise.where(source: @provider.source, is_custom: false, active: true)
              .where.not(source_uid: @seen_uids)
              .update_all(active: false, updated_at: @now.call)
    end

    def rejection_summary
      return nil if @rejections.empty?

      # Aggregated by reason rather than per record: the point is to notice a
      # systematic problem, and a per-record dump would be unreadable at 1,300
      # records and could echo provider content into the database.
      tally = @rejections.flat_map(&:reasons).tally.sort_by { |_, count| -count }
      summary = tally.map { |reason, count| "#{reason} (#{count})" }.join(", ")
      "#{@rejections.size} rejected: #{summary}"
    end
  end
end
