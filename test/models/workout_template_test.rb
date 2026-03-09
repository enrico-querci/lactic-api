require "test_helper"

class WorkoutTemplateTest < ActiveSupport::TestCase
  test "valid workout template" do
    template = workout_templates(:chest_template)
    assert template.valid?
  end

  test "requires name" do
    template = WorkoutTemplate.new(coach: users(:coach_john), source_workout: workouts(:chest_day))
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "requires coach" do
    template = WorkoutTemplate.new(name: "Test", source_workout: workouts(:chest_day))
    assert_not template.valid?
    assert_includes template.errors[:coach], "must exist"
  end

  test "requires source workout" do
    template = WorkoutTemplate.new(name: "Test", coach: users(:coach_john))
    assert_not template.valid?
    assert_includes template.errors[:source_workout], "must exist"
  end
end
