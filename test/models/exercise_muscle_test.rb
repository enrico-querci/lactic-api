require "test_helper"

class ExerciseMuscleTest < ActiveSupport::TestCase
  test "valid primary link" do
    assert exercise_muscles(:situp_primary).valid?
    assert_equal "primary", exercise_muscles(:situp_primary).role
  end

  test "rejects an unknown role" do
    link = ExerciseMuscle.new(exercise: exercises(:bench_press), muscle: muscles(:pectorals), role: "tertiary")
    assert_not link.valid?
    assert_includes link.errors[:role], "is not included in the list"
  end

  test "database rejects an unknown role even without validations" do
    link = ExerciseMuscle.new(exercise: exercises(:bench_press), muscle: muscles(:pectorals), role: "tertiary")
    assert_raises(ActiveRecord::StatementInvalid) { link.save(validate: false) }
  end

  test "the same muscle cannot be linked twice to one exercise" do
    duplicate = ExerciseMuscle.new(exercise: exercises(:provider_situp), muscle: muscles(:abs), role: "secondary")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:muscle_id], "has already been taken"
  end

  test "an exercise may have only one primary muscle" do
    second_primary = ExerciseMuscle.new(
      exercise: exercises(:provider_situp), muscle: muscles(:pectorals), role: "primary"
    )
    assert_not second_primary.valid?
    assert_includes second_primary.errors[:role], "primary muscle already set for this exercise"
  end

  test "database enforces a single primary even without validations" do
    second_primary = ExerciseMuscle.new(
      exercise: exercises(:provider_situp), muscle: muscles(:pectorals), role: "primary"
    )
    assert_raises(ActiveRecord::RecordNotUnique) { second_primary.save(validate: false) }
  end

  test "an exercise may have many secondary muscles" do
    extra = ExerciseMuscle.new(exercise: exercises(:provider_situp), muscle: muscles(:pectorals), role: "secondary")
    assert extra.valid?
    assert extra.save
  end

  test "updating the existing primary does not trip its own uniqueness check" do
    primary = exercise_muscles(:situp_primary)
    primary.muscle = muscles(:pectorals)
    assert primary.valid?
  end

  test "role scopes" do
    links = exercises(:provider_situp).exercise_muscles
    assert_equal [ exercise_muscles(:situp_primary) ], links.primary.to_a
    assert_equal [ exercise_muscles(:situp_secondary) ], links.secondary.to_a
  end
end
