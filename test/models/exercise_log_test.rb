require "test_helper"

class ExerciseLogTest < ActiveSupport::TestCase
  test "valid exercise log" do
    log = exercise_logs(:alice_bench_log)
    assert log.valid?
  end

  test "requires workout session" do
    log = ExerciseLog.new(workout_exercise: workout_exercises(:bench_in_chest_day))
    assert_not log.valid?
    assert_includes log.errors[:workout_session], "must exist"
  end

  test "requires workout exercise" do
    log = ExerciseLog.new(workout_session: workout_sessions(:alice_chest_session))
    assert_not log.valid?
    assert_includes log.errors[:workout_exercise], "must exist"
  end

  test "has many set logs" do
    log = exercise_logs(:alice_bench_log)
    assert_equal 2, log.set_logs.count
  end
end
