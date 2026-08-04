require "test_helper"

class ExerciseTranslationTest < ActiveSupport::TestCase
  test "valid provider translation" do
    assert exercise_translations(:situp_en).valid?
  end

  test "requires a name" do
    translation = ExerciseTranslation.new(exercise: exercises(:provider_situp), locale: "it")
    assert_not translation.valid?
    assert_includes translation.errors[:name], "can't be blank"
  end

  test "rejects an unsupported locale" do
    translation = ExerciseTranslation.new(exercise: exercises(:provider_situp), locale: "fr", name: "Nom")
    assert_not translation.valid?
    assert_includes translation.errors[:locale], "is not included in the list"
  end

  test "rejects an unsupported translation source" do
    translation = ExerciseTranslation.new(
      exercise: exercises(:bench_press), locale: "en", name: "Bench", translation_source: "guessed"
    )
    assert_not translation.valid?
    assert_includes translation.errors[:translation_source], "is not included in the list"
  end

  test "one translation per exercise per locale" do
    duplicate = ExerciseTranslation.new(exercise: exercises(:provider_situp), locale: "en", name: "Duplicate")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:locale], "has already been taken"
  end

  test "database rejects a duplicate locale even without validations" do
    duplicate = ExerciseTranslation.new(exercise: exercises(:provider_situp), locale: "en", name: "Duplicate")
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "instructions must be an array" do
    translation = ExerciseTranslation.new(
      exercise: exercises(:bench_press), locale: "en", name: "Bench", instructions: "not an array"
    )
    assert_not translation.valid?
    assert_includes translation.errors[:instructions], "must be an array of ordered steps"
  end

  test "instructions round-trip as an ordered array" do
    translation = exercise_translations(:situp_en)
    assert_equal 3, translation.instructions.size
    assert_equal "Lie flat on your back with your knees bent.", translation.instructions.first
  end

  test "machine translation is overwritable by a sync" do
    translation = exercise_translations(:situp_it)
    assert_not translation.reviewed?
    assert translation.overwritable_by_sync?
  end

  test "human reviewed translation is protected from a sync" do
    translation = exercise_translations(:treadmill_it)
    assert translation.reviewed?
    assert_not translation.overwritable_by_sync?
  end

  test "translation is stale when the english checksum changed" do
    translation = exercise_translations(:situp_it)
    assert_not translation.stale_for?("c0ffee0001")
    assert translation.stale_for?("something-else")
  end

  test "translation with no recorded checksum is treated as stale" do
    translation = exercise_translations(:situp_it)
    translation.source_checksum = nil
    assert translation.stale_for?("c0ffee0001")
  end

  test "for_locale scope" do
    italian = exercises(:provider_situp).exercise_translations.for_locale(:it)
    assert_equal [ exercise_translations(:situp_it) ], italian.to_a
  end
end
