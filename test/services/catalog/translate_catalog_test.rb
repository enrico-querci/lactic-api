require "test_helper"

module Catalog
  class TranslateCatalogTest < ActiveSupport::TestCase
    class FakeAdapter
      attr_reader :calls

      def initialize = @calls = []
      def configured? = true
      def name = "fake"

      def translate(texts, to:, from: "en")
        @calls << texts
        texts.map { |text| "IT:#{text}" }
      end
    end

    setup do
      @adapter = FakeAdapter.new
      # Start from a clean slate so counts are unambiguous.
      ExerciseTranslation.for_locale("it").destroy_all
    end

    test "translates every catalog exercise that has english" do
      report = TranslateCatalog.call(adapter: @adapter)

      assert_equal 2, report.translated
      assert_equal 2, ExerciseTranslation.for_locale("it").count
      assert_operator report.characters, :>, 0
    end

    test "a second run translates nothing" do
      TranslateCatalog.call(adapter: @adapter)
      @adapter.calls.clear

      report = TranslateCatalog.call(adapter: @adapter)

      assert_equal 0, report.translated
      assert_equal 2, report.skipped
      assert_empty @adapter.calls, "an unchanged catalog must cost nothing"
      assert_equal 0, report.characters
    end

    test "only the exercise whose english changed is retranslated" do
      TranslateCatalog.call(adapter: @adapter)
      exercise_translations(:situp_en).update!(source_checksum: "changed")
      @adapter.calls.clear

      report = TranslateCatalog.call(adapter: @adapter)

      assert_equal 1, report.translated
      assert_equal 1, report.skipped
      assert_equal 1, @adapter.calls.size
    end

    test "human-reviewed rows are counted and left alone" do
      TranslateCatalog.call(adapter: @adapter)
      ExerciseTranslation.for_locale("it").first.update!(
        name: "Rivisto a mano", translation_source: "human", reviewed_at: Time.current
      )
      ExerciseTranslation.for_locale("en").update_all(source_checksum: "changed-everywhere")

      report = TranslateCatalog.call(adapter: @adapter)

      assert_equal 1, report.protected_count
      assert_equal 1, report.translated
      assert_includes ExerciseTranslation.for_locale("it").pluck(:name), "Rivisto a mano"
    end

    test "custom exercises are not translated" do
      # The default scope is the catalog: coach-authored content is theirs.
      exercise = exercises(:custom_exercise)
      exercise.exercise_translations.create!(locale: "en", name: "Coach Special", instructions: [ "Do it." ])

      TranslateCatalog.call(adapter: @adapter)

      assert_empty exercise.exercise_translations.for_locale("it")
    end

    test "an exercise without english is counted, not translated" do
      exercises(:provider_situp).exercise_translations.for_locale("en").destroy_all

      report = TranslateCatalog.call(adapter: @adapter)

      assert_equal 1, report.translated
      # Exercises with no English row are filtered out of the relation, so they
      # are simply never considered.
      assert_equal 1, report.considered
    end

    test "nothing happens when no provider is configured" do
      report = TranslateCatalog.call(adapter: Translation::NullAdapter.new)

      assert_equal 0, report.translated
      assert_equal 0, report.considered
      assert_empty ExerciseTranslation.for_locale("it")
    end

    test "one failing exercise does not abandon the rest" do
      flaky = Class.new(FakeAdapter) do
        def translate(texts, **)
          @seen = (@seen || 0) + 1
          raise Translation::Errors::Transient, "boom" if @seen == 1

          texts.map { |t| "IT:#{t}" }
        end
      end.new

      report = TranslateCatalog.call(adapter: flaky)

      assert_equal 1, report.failed
      assert_equal 1, report.translated
    end

    test "a rejected credential stops the run rather than burning quota" do
      rejecting = Class.new(FakeAdapter) do
        def translate(*, **) = raise(Translation::Errors::Rejected, "quota exceeded")
      end.new

      assert_raises(Translation::Errors::Rejected) { TranslateCatalog.call(adapter: rejecting) }
    end

    test "the report reads as a sentence for the rake task" do
      report = TranslateCatalog.call(adapter: @adapter)

      assert_includes report.to_s, "translated"
      assert_includes report.to_s, "characters sent"
    end
  end
end
