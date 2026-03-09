require "test_helper"

class WorkoutExerciseTest < ActiveSupport::TestCase
  test "valid workout exercise" do
    we = workout_exercises(:bench_in_chest_day)
    assert we.valid?
  end

  test "requires position" do
    we = WorkoutExercise.new(workout: workouts(:chest_day), exercise: exercises(:bench_press), sets: 3, reps: 10)
    assert_not we.valid?
    assert_includes we.errors[:position], "can't be blank"
  end

  test "position must be uppercase letter" do
    we = WorkoutExercise.new(workout: workouts(:leg_day), exercise: exercises(:bench_press),
                             position: "a", sets: 3, reps: 10)
    assert_not we.valid?
    assert_includes we.errors[:position], "must be a single uppercase letter (A-Z)"
  end

  test "position must be unique within workout" do
    we = WorkoutExercise.new(workout: workouts(:chest_day), exercise: exercises(:squat),
                             position: "A", sets: 3, reps: 10)
    assert_not we.valid?
    assert_includes we.errors[:position], "has already been taken"
  end

  test "requires sets" do
    we = WorkoutExercise.new(workout: workouts(:leg_day), exercise: exercises(:bench_press),
                             position: "B", reps: 10)
    assert_not we.valid?
    assert_includes we.errors[:sets], "can't be blank"
  end

  test "sets must be positive" do
    we = WorkoutExercise.new(workout: workouts(:leg_day), exercise: exercises(:bench_press),
                             position: "B", sets: 0, reps: 10)
    assert_not we.valid?
    assert_includes we.errors[:sets], "must be greater than 0"
  end

  test "requires reps" do
    we = WorkoutExercise.new(workout: workouts(:leg_day), exercise: exercises(:bench_press),
                             position: "B", sets: 3)
    assert_not we.valid?
    assert_includes we.errors[:reps], "can't be blank"
  end

  test "weight must be non-negative" do
    we = workout_exercises(:bench_in_chest_day)
    we.weight = -1
    assert_not we.valid?
    assert_includes we.errors[:weight], "must be greater than or equal to 0"
  end

  test "rir must be non-negative" do
    we = workout_exercises(:bench_in_chest_day)
    we.rir = -1
    assert_not we.valid?
    assert_includes we.errors[:rir], "must be greater than or equal to 0"
  end
end
