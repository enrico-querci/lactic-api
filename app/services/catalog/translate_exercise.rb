module Catalog
  # Produces the Italian translation for one exercise.
  #
  # Rules the plan sets, and where each is enforced:
  #
  #   * never during a user request — this is only reachable from the sync
  #     task, never from a controller;
  #   * regenerate only when the English changed — `#stale?` compares the
  #     stored source_checksum against the English translation's;
  #   * a human-reviewed translation is never overwritten — checked before any
  #     provider call is made, so protection also saves money;
  #   * name and instructions are translated, the description is generated from
  #     the glossary (see DescriptionBuilder for why);
  #   * provenance and source checksum are stored so the next run can tell what
  #     is stale.
  class TranslateExercise
    LOCALE = "it".freeze
    SOURCE_LOCALE = "en".freeze

    Result = Data.define(:status, :characters) do
      def translated? = status == :translated
    end

    SKIPPED = Result.new(status: :skipped, characters: 0)
    PROTECTED = Result.new(status: :protected, characters: 0)
    NO_SOURCE = Result.new(status: :no_source, characters: 0)

    def self.call(...) = new(...).call

    def initialize(exercise, adapter:)
      @exercise = exercise
      @adapter = adapter
    end

    def call
      source = exercise.exercise_translations.detect { |t| t.locale == SOURCE_LOCALE }
      return NO_SOURCE if source.nil? || source.name.blank?

      existing = exercise.exercise_translations.detect { |t| t.locale == LOCALE }

      # Checked before translating, not after: a protected row must not cost a
      # provider call either.
      return PROTECTED if existing && !existing.overwritable_by_sync?
      return SKIPPED if existing && !existing.stale_for?(source.source_checksum)

      write(existing, source)
    end

    private

    attr_reader :exercise, :adapter

    def write(existing, source)
      segments = [ source.name ] + Array(source.instructions)
      translated = adapter.translate(segments, to: LOCALE, from: SOURCE_LOCALE)

      # Alignment is the contract. If it breaks, instructions would be
      # reordered silently, so fail rather than persist nonsense.
      unless translated.size == segments.size
        raise Translation::Errors::Schema,
          "expected #{segments.size} translations, got #{translated.size}"
      end

      name = translated.first.presence || source.name
      instructions = translated.drop(1)

      record = existing || exercise.exercise_translations.build(locale: LOCALE)
      record.assign_attributes(
        name: name,
        # Generated rather than translated: the English is itself generated.
        description: Translation::DescriptionBuilder.call(exercise, name: name),
        instructions: instructions,
        translation_source: "machine",
        source_checksum: source.source_checksum
      )
      record.save!

      Result.new(status: :translated, characters: segments.sum(&:length))
    end
  end
end
