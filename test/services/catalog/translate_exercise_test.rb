require "test_helper"

module Catalog
  class TranslateExerciseTest < ActiveSupport::TestCase
    # Records what it was asked to translate, so tests can assert that a
    # protected or unchanged row costs no provider call at all — the plan's
    # "repeating an unchanged sync incurs no translation call".
    class FakeAdapter
      attr_reader :calls

      def initialize(prefix: "IT:")
        @prefix = prefix
        @calls = []
      end

      def configured? = true
      def name = "fake"

      def translate(texts, to:, from: "en")
        @calls << { texts: texts, to: to, from: from }
        texts.map { |text| "#{@prefix}#{text}" }
      end
    end

    class FailingAdapter < FakeAdapter
      def translate(*, **)
        raise Translation::Errors::Transient, "network failure"
      end
    end

    setup do
      @exercise = exercises(:provider_situp)
      @adapter = FakeAdapter.new
      @english = exercise_translations(:situp_en)
    end

    def italian(exercise = @exercise)
      exercise.exercise_translations.reload.detect { |t| t.locale == "it" }
    end

    def translate(exercise = @exercise, adapter: @adapter)
      TranslateExercise.call(exercise.reload, adapter: adapter)
    end

    # --- Generation ---------------------------------------------------------

    test "translates name and every instruction step" do
      italian(@exercise).destroy!

      result = translate

      assert result.translated?
      assert_equal "IT:3/4 Sit-up", italian.name
      assert_equal 3, italian.instructions.size
      assert_equal "IT:Lie flat on your back with your knees bent.", italian.instructions.first
    end

    test "instruction order is preserved" do
      italian(@exercise).destroy!
      translate

      assert_equal @english.instructions.map { |s| "IT:#{s}" }, italian.instructions
    end

    test "records provenance and the checksum it was derived from" do
      italian(@exercise).destroy!
      translate

      assert_equal "machine", italian.translation_source
      assert_equal @english.source_checksum, italian.source_checksum
      assert_nil italian.reviewed_at
    end

    test "the description is generated from the glossary, not translated" do
      italian(@exercise).destroy!
      translate

      sent = @adapter.calls.flat_map { |call| call[:texts] }
      assert_not_includes sent, @english.description,
        "the english description must never be sent: it is itself generated, so paying to translate it is waste"

      description = italian.description
      # Glossary terms, not translator output. The name is the only translated
      # fragment in the sentence, which is why it carries the fake's prefix.
      assert_includes description, "Addominali"        # target muscle
      assert_includes description, "Corpo libero"      # equipment
      assert_includes description, "forza"             # category
      assert_includes description, "Flessori dell'anca" # secondary muscle
      assert_equal 1, description.scan("IT:").size
    end

    # --- Staleness ----------------------------------------------------------

    test "an unchanged exercise costs no provider call" do
      # The fixture Italian already carries the English checksum.
      result = translate

      assert_equal :skipped, result.status
      assert_empty @adapter.calls
      assert_equal 0, result.characters
    end

    test "changed english regenerates unreviewed italian" do
      @english.update!(name: "Renamed", source_checksum: "new-checksum")

      result = translate

      assert result.translated?
      assert_equal "IT:Renamed", italian.name
      assert_equal "new-checksum", italian.source_checksum
    end

    test "italian with no recorded checksum is regenerated once" do
      italian(@exercise).update!(source_checksum: nil)

      assert translate.translated?
      assert_equal @english.source_checksum, italian.source_checksum
    end

    # --- Human review protection -------------------------------------------

    test "a human-reviewed translation is never overwritten" do
      italian(@exercise).update!(
        name: "Nome scelto dal coach", translation_source: "human", reviewed_at: Time.current
      )
      @english.update!(source_checksum: "changed-since")

      result = translate

      assert_equal :protected, result.status
      assert_equal "Nome scelto dal coach", italian.name
    end

    test "a protected translation costs no provider call either" do
      italian(@exercise).update!(translation_source: "human", reviewed_at: Time.current)
      @english.update!(source_checksum: "changed-since")

      translate

      assert_empty @adapter.calls, "must not pay to translate something it will discard"
    end

    test "a reviewed_at marker alone protects the row" do
      italian(@exercise).update!(reviewed_at: Time.current, source_checksum: "stale")

      assert_equal :protected, translate.status
    end

    # --- Missing source -----------------------------------------------------

    test "an exercise with no english is reported rather than translated" do
      exercise = exercises(:bench_press)

      result = translate(exercise)

      assert_equal :no_source, result.status
      assert_empty @adapter.calls
    end

    # --- Failure ------------------------------------------------------------

    test "a provider failure propagates rather than writing partial content" do
      italian(@exercise).destroy!

      assert_raises(Translation::Errors::Transient) do
        translate(adapter: FailingAdapter.new)
      end

      assert_nil italian
    end

    test "a misaligned response is refused rather than persisted" do
      italian(@exercise).destroy!
      short = Class.new(FakeAdapter) do
        def translate(texts, **) = [ "only one" ]
      end.new

      assert_raises(Translation::Errors::Schema) { translate(adapter: short) }
      assert_nil italian
    end

    # --- Character accounting ----------------------------------------------

    test "reports the characters sent, which is what the provider bills for" do
      italian(@exercise).destroy!

      result = translate

      expected = ([ @english.name ] + @english.instructions).sum(&:length)
      assert_equal expected, result.characters
    end
  end
end
