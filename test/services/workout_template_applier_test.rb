require "test_helper"

class WorkoutTemplateApplierTest < ActiveSupport::TestCase
  setup do
    @template = workout_templates(:chest_template)
    @week = weeks(:week_two)
  end

  test "creates a workout named after the template with its exercises" do
    workout = WorkoutTemplateApplier.call(template: @template, target_week: @week, day: 2)

    assert_equal @template.name, workout.name
    assert_equal 2, workout.day
    assert_equal @week, workout.week
    assert_equal %w[A B], workout.workout_exercises.map(&:position)

    bench = workout.workout_exercises.find_by!(position: "A")
    assert_equal exercises(:bench_press), bench.exercise
    assert_equal [ 4, 10, 90, 2, 60 ], [ bench.sets, bench.reps, bench.rest_seconds, bench.rir, bench.weight.to_i ]
  end

  test "each application is an independent copy" do
    monday = WorkoutTemplateApplier.call(template: @template, target_week: @week, day: 1)
    wednesday = WorkoutTemplateApplier.call(template: @template, target_week: @week, day: 3)

    monday.workout_exercises.find_by!(position: "A").update!(weight: 80, sets: 5)

    wed_bench = wednesday.workout_exercises.find_by!(position: "A")
    assert_equal [ 4, 60 ], [ wed_bench.sets, wed_bench.weight.to_i ]
    assert_equal [ 4, 60 ], [ @template.workout_template_exercises.first.sets, @template.workout_template_exercises.first.weight.to_i ]
  end

  test "creates nothing when the day is invalid" do
    assert_no_difference [ "Workout.count", "WorkoutExercise.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        WorkoutTemplateApplier.call(template: @template, target_week: @week, day: 0)
      end
    end
  end

  test "still applies after the source workout was deleted" do
    @template.source_workout.destroy!

    workout = WorkoutTemplateApplier.call(template: @template.reload, target_week: @week, day: 5)
    assert_equal 2, workout.workout_exercises.count
  end
end
