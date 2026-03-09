require "test_helper"

class SetLogTest < ActiveSupport::TestCase
  test "valid set log" do
    set_log = set_logs(:bench_set_one)
    assert set_log.valid?
  end

  test "requires position" do
    set_log = SetLog.new(exercise_log: exercise_logs(:alice_bench_log), weight_kg: 60, reps: 10)
    assert_not set_log.valid?
    assert_includes set_log.errors[:position], "can't be blank"
  end

  test "position must be unique within exercise log" do
    set_log = SetLog.new(exercise_log: exercise_logs(:alice_bench_log), position: 1, weight_kg: 60, reps: 10)
    assert_not set_log.valid?
    assert_includes set_log.errors[:position], "has already been taken"
  end

  test "requires weight_kg" do
    set_log = SetLog.new(exercise_log: exercise_logs(:alice_bench_log), position: 3, reps: 10)
    assert_not set_log.valid?
    assert_includes set_log.errors[:weight_kg], "can't be blank"
  end

  test "weight_kg must be non-negative" do
    set_log = SetLog.new(exercise_log: exercise_logs(:alice_bench_log), position: 3, weight_kg: -1, reps: 10)
    assert_not set_log.valid?
    assert_includes set_log.errors[:weight_kg], "must be greater than or equal to 0"
  end

  test "requires reps" do
    set_log = SetLog.new(exercise_log: exercise_logs(:alice_bench_log), position: 3, weight_kg: 60)
    assert_not set_log.valid?
    assert_includes set_log.errors[:reps], "can't be blank"
  end

  test "reps must be positive" do
    set_log = SetLog.new(exercise_log: exercise_logs(:alice_bench_log), position: 3, weight_kg: 60, reps: 0)
    assert_not set_log.valid?
    assert_includes set_log.errors[:reps], "must be greater than 0"
  end

  test "default scope orders by position" do
    log = exercise_logs(:alice_bench_log)
    assert_equal [1, 2], log.set_logs.map(&:position)
  end
end
