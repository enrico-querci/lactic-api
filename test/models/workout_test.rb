require "test_helper"

class WorkoutTest < ActiveSupport::TestCase
  test "valid workout" do
    workout = workouts(:chest_day)
    assert workout.valid?
  end

  test "requires name" do
    workout = Workout.new(week: weeks(:week_one), day: 1)
    assert_not workout.valid?
    assert_includes workout.errors[:name], "can't be blank"
  end

  test "requires day" do
    workout = Workout.new(week: weeks(:week_one), name: "Test")
    assert_not workout.valid?
    assert_includes workout.errors[:day], "can't be blank"
  end

  test "day must be between 1 and 7" do
    workout = Workout.new(week: weeks(:week_one), name: "Test", day: 0)
    assert_not workout.valid?

    workout.day = 8
    assert_not workout.valid?

    workout.day = 5
    assert workout.valid?
  end

  test "volume_sets returns sets grouped by muscle group" do
    workout = workouts(:chest_day)
    volume = workout.volume_sets
    # bench_press: 4 sets (Chest) + bicep_curl: 3 sets (Biceps)
    assert_equal 4, volume["Chest"]
    assert_equal 3, volume["Biceps"]
  end

  test "has many workout_exercises" do
    workout = workouts(:chest_day)
    assert_equal 2, workout.workout_exercises.count
  end
end
