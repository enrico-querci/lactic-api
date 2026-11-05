require "test_helper"

class WorkoutTemplateExerciseTest < ActiveSupport::TestCase
  setup do
    @template = workout_templates(:chest_template)
  end

  test "fixtures are valid" do
    assert workout_template_exercises(:bench_in_chest_template).valid?
  end

  test "position must be a single uppercase letter" do
    exercise = @template.workout_template_exercises.build(exercise: exercises(:squat), position: "AB", sets: 3, reps: 8)
    assert_not exercise.valid?
    assert exercise.errors[:position].any?
  end

  test "position is unique within a template" do
    exercise = @template.workout_template_exercises.build(exercise: exercises(:squat), position: "A", sets: 3, reps: 8)
    assert_not exercise.valid?
    assert_includes exercise.errors[:position], "has already been taken"
  end

  test "sets and reps must be positive" do
    exercise = @template.workout_template_exercises.build(exercise: exercises(:squat), position: "C", sets: 0, reps: 0)
    assert_not exercise.valid?
    assert exercise.errors[:sets].any?
    assert exercise.errors[:reps].any?
  end

  test "destroying an exercise destroys the template copies of it" do
    assert_difference "WorkoutTemplateExercise.count", -1 do
      exercises(:bench_press).destroy!
    end
  end
end
