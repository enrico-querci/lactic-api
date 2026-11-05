require "test_helper"

class WorkoutTemplateTest < ActiveSupport::TestCase
  test "valid workout template" do
    template = workout_templates(:chest_template)
    assert template.valid?
  end

  test "requires name" do
    template = WorkoutTemplate.new(coach: users(:coach_john))
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "requires coach" do
    template = WorkoutTemplate.new(name: "Test")
    assert_not template.valid?
    assert_includes template.errors[:coach], "must exist"
  end

  test "does not require a source workout" do
    template = WorkoutTemplate.new(name: "Test", coach: users(:coach_john))
    assert template.valid?
  end

  test "deleting the source workout keeps the template and its exercises" do
    template = workout_templates(:chest_template)

    assert_no_difference [ "WorkoutTemplate.count", "WorkoutTemplateExercise.count" ] do
      template.source_workout.destroy!
    end

    assert_nil template.reload.source_workout_id
    assert_equal %w[A B], template.workout_template_exercises.map(&:position)
  end

  test "deleting the source workout's whole programme keeps the template" do
    template = workout_templates(:chest_template)

    assert_no_difference "WorkoutTemplate.count" do
      template.source_workout.week.program.destroy!
    end
  end

  test "destroying a template destroys its exercises" do
    assert_difference "WorkoutTemplateExercise.count", -2 do
      workout_templates(:chest_template).destroy!
    end
  end
end
