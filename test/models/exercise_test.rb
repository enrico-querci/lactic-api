require "test_helper"

class ExerciseTest < ActiveSupport::TestCase
  test "valid catalog exercise" do
    exercise = exercises(:bench_press)
    assert exercise.valid?
    assert_not exercise.is_custom?
  end

  test "valid custom exercise" do
    exercise = exercises(:custom_exercise)
    assert exercise.valid?
    assert exercise.is_custom?
    assert_equal users(:coach_john), exercise.coach
  end

  test "requires name" do
    exercise = Exercise.new(muscle_group: "Chest")
    assert_not exercise.valid?
    assert_includes exercise.errors[:name], "can't be blank"
  end

  test "requires muscle_group" do
    exercise = Exercise.new(name: "Test")
    assert_not exercise.valid?
    assert_includes exercise.errors[:muscle_group], "can't be blank"
  end

  test "custom exercise requires coach" do
    exercise = Exercise.new(name: "Custom", muscle_group: "Chest", is_custom: true)
    assert_not exercise.valid?
    assert_includes exercise.errors[:coach_id], "is required for custom exercises"
  end

  test "catalog scope" do
    catalog = Exercise.catalog
    assert_includes catalog, exercises(:bench_press)
    assert_not_includes catalog, exercises(:custom_exercise)
  end

  test "custom scope" do
    custom = Exercise.custom
    assert_includes custom, exercises(:custom_exercise)
    assert_not_includes custom, exercises(:bench_press)
  end

  test "for_coach scope includes catalog and coach custom exercises" do
    coach = users(:coach_john)
    available = Exercise.for_coach(coach.id)
    assert_includes available, exercises(:bench_press)
    assert_includes available, exercises(:custom_exercise)
  end

  # --- Provider catalog records ------------------------------------------

  test "valid provider exercise" do
    exercise = exercises(:provider_situp)
    assert exercise.valid?
    assert exercise.from_provider?
    assert_not exercise.custom?
    assert_equal "workoutx", exercise.source
    assert_equal "0001", exercise.source_uid
  end

  test "source_uid is stored as a string so zero padding survives" do
    assert_equal "0001", exercises(:provider_situp).source_uid
    assert_not_equal 1, exercises(:provider_situp).source_uid
  end

  test "catalog exercise cannot have a coach" do
    exercise = exercises(:bench_press)
    exercise.coach = users(:coach_john)
    assert_not exercise.valid?
    assert_includes exercise.errors[:coach_id], "must be blank for catalog exercises"
  end

  test "database enforces custom ownership even without validations" do
    exercise = exercises(:bench_press)
    exercise.coach_id = users(:coach_john).id
    assert_raises(ActiveRecord::StatementInvalid) { exercise.save(validate: false) }
  end

  test "custom exercise cannot carry a provider identity" do
    exercise = exercises(:custom_exercise)
    exercise.source = "workoutx"
    exercise.source_uid = "9999"
    assert_not exercise.valid?
    assert_includes exercise.errors[:source], "must be blank for custom exercises"
  end

  test "source and source_uid must be set together" do
    exercise = Exercise.new(name: "Half", muscle_group: "Abs", source: "workoutx")
    assert_not exercise.valid?
    assert_includes exercise.errors[:source_uid], "and source must be set together"
  end

  test "provider identity is unique per source" do
    duplicate = Exercise.new(name: "Copy", muscle_group: "Abs", source: "workoutx", source_uid: "0001")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:source_uid], "has already been taken"
  end

  test "database enforces provider identity uniqueness even without validations" do
    duplicate = Exercise.new(name: "Copy", muscle_group: "Abs", source: "workoutx", source_uid: "0001")
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "the same source_uid may exist under a different source" do
    other = Exercise.new(name: "Other", muscle_group: "Abs", source: "elsewhere", source_uid: "0001")
    assert other.valid?
  end

  test "provider and custom records coexist without ambiguous ownership" do
    provider = exercises(:provider_situp)
    custom = exercises(:custom_exercise)

    assert provider.from_provider?
    assert_nil provider.coach_id
    assert custom.custom?
    assert_equal users(:coach_john), custom.coach
    assert_nil custom.source
  end

  test "prescription_type defaults to repetitions" do
    exercise = Exercise.create!(name: "New", muscle_group: "Abs")
    assert_equal "repetitions", exercise.prescription_type
  end

  test "rejects an unsupported prescription type" do
    exercise = Exercise.new(name: "Plank", muscle_group: "Abs", prescription_type: "seconds")
    assert_not exercise.valid?
    assert_includes exercise.errors[:prescription_type], "is not included in the list"
  end

  # --- Selectable / assignability ----------------------------------------

  test "active and assignable default to true" do
    exercise = Exercise.create!(name: "New", muscle_group: "Abs")
    assert exercise.active?
    assert exercise.assignable?
  end

  test "selectable excludes exercises that are not assignable" do
    selectable = Exercise.selectable(users(:coach_john).id)
    assert_includes selectable, exercises(:provider_situp)
    assert_includes selectable, exercises(:custom_exercise)
    assert_not_includes selectable, exercises(:provider_treadmill)
  end

  test "selectable excludes inactive exercises" do
    exercises(:provider_situp).update!(active: false)
    assert_not_includes Exercise.selectable(users(:coach_john).id), exercises(:provider_situp)
  end

  test "for_coach still resolves an unassignable exercise so history keeps working" do
    assert_includes Exercise.for_coach(users(:coach_john).id), exercises(:provider_treadmill)
  end

  test "selectable excludes another coach's custom exercise" do
    other_coach = User.create!(name: "Other", email: "other@example.com", role: "coach")
    assert_not_includes Exercise.selectable(other_coach.id), exercises(:custom_exercise)
  end

  # --- Localization -------------------------------------------------------

  test "translation_for returns the requested locale" do
    assert_equal exercise_translations(:situp_it), exercises(:provider_situp).translation_for("it")
  end

  test "translation_for accepts a symbol locale" do
    assert_equal exercise_translations(:situp_it), exercises(:provider_situp).translation_for(:it)
  end

  test "translation_for falls back to english when the locale is missing" do
    exercise = exercises(:provider_situp)
    exercise.exercise_translations.for_locale("it").destroy_all

    assert_equal exercise_translations(:situp_en), exercise.reload.translation_for("it")
  end

  test "translation_for falls back to english for a locale never supported" do
    assert_equal exercise_translations(:situp_en), exercises(:provider_situp).translation_for("de")
  end

  test "translation_for falls back to any translation when english is missing" do
    exercise = exercises(:provider_situp)
    exercise.exercise_translations.for_locale("en").destroy_all

    assert_equal exercise_translations(:situp_it), exercise.reload.translation_for("de")
  end

  test "translation_for returns nil when an exercise has no translations" do
    assert_nil exercises(:bench_press).translation_for("en")
  end

  test "translation_for handles a blank locale" do
    assert_equal exercise_translations(:situp_en), exercises(:provider_situp).translation_for(nil)
    assert_equal exercise_translations(:situp_en), exercises(:provider_situp).translation_for("")
  end

  test "localized_name uses the translation" do
    assert_equal "Sit-up 3/4", exercises(:provider_situp).localized_name("it")
  end

  test "localized_name falls back to the legacy column for untranslated records" do
    assert_equal "Bench Press", exercises(:bench_press).localized_name("it")
  end

  # --- Associations -------------------------------------------------------

  test "primary and secondary muscles" do
    exercise = exercises(:provider_situp)
    assert_equal muscles(:abs), exercise.primary_muscle
    assert_equal [ muscles(:hip_flexors) ], exercise.secondary_muscles
  end

  test "exercise without muscle links has no primary muscle" do
    assert_nil exercises(:bench_press).primary_muscle
    assert_empty exercises(:bench_press).secondary_muscles
  end

  test "legacy muscle_group mirrors the primary muscle for provider records" do
    exercise = exercises(:provider_situp)
    assert_equal exercise.primary_muscle.name, exercise.muscle_group
  end

  test "destroying an exercise destroys its catalog associations" do
    exercise = exercises(:provider_situp)

    assert_difference [ "ExerciseTranslation.count", "ExerciseMuscle.count" ], -2 do
      assert_difference [ "ExerciseEquipment.count", "ExerciseMedium.count" ], -1 do
        exercise.destroy!
      end
    end
  end

  test "destroying an exercise leaves shared taxonomy rows alone" do
    exercises(:provider_situp).destroy!
    assert Muscle.exists?(muscles(:abs).id)
    assert Equipment.exists?(equipment(:body_weight).id)
  end
end
