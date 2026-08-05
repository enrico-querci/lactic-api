module Catalog
  # Runs the Italian translation pass across the catalog.
  #
  # Counts and character totals are recorded because the provider bills per
  # character: without them there is no way to see a cost regression, and the
  # plan asks for cost and count instrumentation. Exercise content is never
  # logged, only sizes.
  class TranslateCatalog
    Report = Data.define(
      :translated, :skipped, :protected_count, :no_source, :failed, :characters
    ) do
      def considered = translated + skipped + protected_count + no_source + failed

      def to_s
        "#{translated} translated, #{skipped} already current, " \
          "#{protected_count} human-reviewed and left alone, #{no_source} without english, " \
          "#{failed} failed; #{characters} characters sent"
      end
    end

    def self.call(...) = new(...).call

    def initialize(adapter: nil, scope: nil, batch_size: 200)
      @adapter = adapter || default_adapter
      @scope = scope || Exercise.catalog
      @batch_size = batch_size
    end

    # Returns a Report. Raises only if the provider fails in a way that would
    # make continuing pointless — bad credentials or exhausted quota. A single
    # exercise failing is counted and stepped over, the same way the importer
    # quarantines one bad record rather than losing the page.
    def call
      return empty_report unless @adapter.configured?

      counts = Hash.new(0)
      characters = 0

      relation.find_each(batch_size: @batch_size) do |exercise|
        result = TranslateExercise.call(exercise, adapter: @adapter)
        counts[result.status] += 1
        characters += result.characters
      rescue Translation::Errors::Rejected
        # Credentials or quota: every subsequent call would fail the same way
        # and cost money doing it.
        raise
      rescue Translation::Errors::Base, ActiveRecord::ActiveRecordError => e
        counts[:failed] += 1
        Rails.logger.warn("catalog_translation exercise_id=#{exercise.id} error=#{e.class}")
      end

      build_report(counts, characters)
    end

    private

    # Only records that have English to translate from, preloaded so the
    # per-exercise service does not issue a query per association.
    def relation
      @scope.where(id: ExerciseTranslation.for_locale("en").select(:exercise_id))
            .includes(:exercise_translations, :equipment, exercise_muscles: :muscle)
    end

    def default_adapter
      google = Translation::GoogleAdapter.new
      google.configured? ? google : Translation::NullAdapter.new
    end

    def empty_report
      Rails.logger.info("catalog_translation skipped: no translation provider configured")
      Report.new(translated: 0, skipped: 0, protected_count: 0, no_source: 0, failed: 0, characters: 0)
    end

    def build_report(counts, characters)
      report = Report.new(
        translated: counts[:translated],
        skipped: counts[:skipped],
        protected_count: counts[:protected],
        no_source: counts[:no_source],
        failed: counts[:failed],
        characters: characters
      )
      Rails.logger.info("catalog_translation provider=#{@adapter.name} #{report}")
      report
    end
  end
end
