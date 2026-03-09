require "test_helper"

class WeekTest < ActiveSupport::TestCase
  test "valid week" do
    week = weeks(:week_one)
    assert week.valid?
  end

  test "requires position" do
    week = Week.new(program: programs(:strength_program))
    assert_not week.valid?
    assert_includes week.errors[:position], "can't be blank"
  end

  test "position must be integer" do
    week = Week.new(program: programs(:strength_program), position: 1.5)
    assert_not week.valid?
    assert_includes week.errors[:position], "must be an integer"
  end

  test "position must be unique within program" do
    week = Week.new(program: programs(:strength_program), position: 1)
    assert_not week.valid?
    assert_includes week.errors[:position], "has already been taken"
  end

  test "default scope orders by position" do
    program = programs(:strength_program)
    assert_equal [1, 2], program.weeks.map(&:position)
  end

  test "has many workouts" do
    week = weeks(:week_one)
    assert_equal 2, week.workouts.count
  end
end
