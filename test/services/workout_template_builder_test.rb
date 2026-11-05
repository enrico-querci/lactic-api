require "test_helper"

class WorkoutTemplateBuilderTest < ActiveSupport::TestCase
  setup do
    @coach = users(:coach_john)
    @workout = workouts(:chest_day)
  end

  test "copies the workout's exercises with their prescription" do
    template = WorkoutTemplateBuilder.call(coach: @coach, name: "Chest", workout: @workout)

    assert_equal @coach, template.coach
    assert_equal @workout, template.source_workout
    assert_equal @workout.workout_exercises.count, template.workout_template_exercises.count

    bench = template.workout_template_exercises.find_by!(position: "A")
    assert_equal exercises(:bench_press), bench.exercise
    assert_equal [ 4, 10, 90, 2, 60 ], [ bench.sets, bench.reps, bench.rest_seconds, bench.rir, bench.weight.to_i ]
  end

  test "later edits to the workout do not change the template" do
    template = WorkoutTemplateBuilder.call(coach: @coach, name: "Chest", workout: @workout)

    @workout.workout_exercises.find_by!(position: "A").update!(sets: 9, weight: 100)
    @workout.workout_exercises.find_by!(position: "B").destroy!

    copies = template.reload.workout_template_exercises
    assert_equal 2, copies.size
    assert_equal [ 4, 60 ], [ copies.first.sets, copies.first.weight.to_i ]
  end

  test "saves nothing when the name is blank" do
    assert_no_difference [ "WorkoutTemplate.count", "WorkoutTemplateExercise.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        WorkoutTemplateBuilder.call(coach: @coach, name: "", workout: @workout)
      end
    end
  end
end
