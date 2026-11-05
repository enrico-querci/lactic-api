require "test_helper"

class WorkoutTemplateExerciseReplacerTest < ActiveSupport::TestCase
  setup do
    @coach = users(:coach_john)
    @template = workout_templates(:chest_template)
  end

  def item(exercise, **overrides)
    { exercise_id: exercise.id, sets: 3, reps: 8, rest_seconds: 60 }.merge(overrides).with_indifferent_access
  end

  def replace(items)
    WorkoutTemplateExerciseReplacer.call(template: @template, coach: @coach, items: items)
  end

  test "replaces the exercises and numbers them from the order of the list" do
    replace([ item(exercises(:squat)), item(exercises(:bench_press), sets: 5), item(exercises(:bicep_curl)) ])

    rows = @template.workout_template_exercises
    assert_equal %w[A B C], rows.map(&:position)
    assert_equal [ exercises(:squat), exercises(:bench_press), exercises(:bicep_curl) ], rows.map(&:exercise)
    assert_equal 5, rows.second.sets
  end

  test "keeps the optional fields" do
    replace([ item(exercises(:squat), rir: 1, weight: 42.5, notes: "slow") ])

    row = @template.workout_template_exercises.first
    assert_equal [ 1, "slow" ], [ row.rir, row.notes ]
    assert_equal 42.5, row.weight.to_f
  end

  test "an empty list clears the template" do
    assert_difference "WorkoutTemplateExercise.count", -2 do
      replace([])
    end
    assert_empty @template.workout_template_exercises
  end

  test "the same exercise may appear twice" do
    replace([ item(exercises(:squat)), item(exercises(:squat), reps: 12) ])
    assert_equal [ 8, 12 ], @template.workout_template_exercises.map(&:reps)
  end

  test "an invalid item changes nothing" do
    assert_no_difference "WorkoutTemplateExercise.count" do
      assert_raises(ActiveRecord::RecordInvalid) { replace([ item(exercises(:squat)), item(exercises(:bench_press), sets: 0) ]) }
    end
    assert_equal %w[A B], @template.reload.workout_template_exercises.map(&:position)
    assert_equal exercises(:bench_press), @template.workout_template_exercises.first.exercise
  end

  test "an exercise the coach cannot pick changes nothing" do
    assert_no_difference "WorkoutTemplateExercise.count" do
      assert_raises(ActiveRecord::RecordNotFound) { replace([ item(exercises(:provider_treadmill)) ]) }
      assert_raises(ActiveRecord::RecordNotFound) { replace([ item(exercises(:squat)).merge(exercise_id: 0) ]) }
    end
  end

  test "more than 26 exercises are refused" do
    assert_no_difference "WorkoutTemplateExercise.count" do
      error = assert_raises(ActiveRecord::RecordInvalid) { replace(Array.new(27) { item(exercises(:squat)) }) }
      assert_match(/at most 26/, error.message)
    end
  end

  test "exactly 26 exercises are accepted" do
    replace(Array.new(26) { item(exercises(:squat)) })
    assert_equal 26, @template.workout_template_exercises.count
  end
end
