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
end
