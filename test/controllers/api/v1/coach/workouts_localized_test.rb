require "test_helper"

# Stage 5 follow-up: volume_sets and nested exercise names localize once a
# locale reaches WorkoutBlueprint. Kept separate from the pre-existing
# workouts controller test for the same reason exercises_localized_test.rb
# is separate from its own predecessor.
class Api::V1::Coach::WorkoutsLocalizedTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @program = programs(:strength_program)
    @week = weeks(:week_two)
    @mixed_day = workouts(:mixed_vocabulary_day)
  end

  def show(headers: {})
    get "/api/v1/coach/programs/#{@program.id}/weeks/#{@week.id}/workouts/#{@mixed_day.id}",
      headers: auth_headers_for(@coach).merge(headers)
    JSON.parse(response.body)
  end

  test "english volume_sets is unchanged by locale awareness" do
    # mixed_vocabulary_day carries three exercises: bench_press (Chest, 4),
    # provider_chest_press (Pectorals, 5), bicep_curl (Biceps, 3) — three
    # distinct English keys, byte-identical to pre-locale behaviour.
    json = show

    assert_equal({ "Chest" => 4, "Pectorals" => 5, "Biceps" => 3 }, json["volume_sets"])
  end

  test "italian volume_sets sums the colliding vocabularies into one badge" do
    json = show(headers: { "Accept-Language" => "it" })

    assert_equal({ "Pettorali" => 9, "Bicipiti" => 3 }, json["volume_sets"])
  end

  test "no sets are lost in the italian merge" do
    en_total = show["volume_sets"].values.sum
    it_total = show(headers: { "Accept-Language" => "it" })["volume_sets"].values.sum

    assert_equal en_total, it_total
  end

  test "italian also localizes nested exercise names, as a known consequence" do
    # ExerciseBlueprint#name already localizes via Exercise#localized_name.
    # WorkoutBlueprint's :extended view nests workout_exercises -> exercise,
    # so passing locale: to reach volume_sets reaches this too. Pinned here
    # rather than left for a reviewer to discover. Inert in production today
    # (zero `it` exercise_translations rows exist), but real the moment a
    # translation exists — provider_situp's fixture translation proves the
    # mechanism now rather than waiting for real content to expose it.
    exercise = exercises(:provider_situp)
    workout = workouts(:leg_day)
    workout.workout_exercises.create!(exercise: exercise, position: "Z", sets: 1, reps: 1, rest_seconds: 30)

    get "/api/v1/coach/programs/#{@program.id}/weeks/#{workout.week_id}/workouts/#{workout.id}",
      headers: auth_headers_for(@coach).merge("Accept-Language" => "it")
    names = JSON.parse(response.body)["workout_exercises"].map { |we| we["exercise"]["name"] }

    assert_includes names, "Sit-up 3/4"
  end

  test "primary_muscle key stays stable across locales while name translates" do
    workout = workouts(:leg_day)
    workout.workout_exercises.create!(
      exercise: exercises(:provider_situp), position: "Z", sets: 1, reps: 1, rest_seconds: 30
    )

    get "/api/v1/coach/workouts/#{workout.id}/workout_exercises", headers: auth_headers_for(@coach)
    en_muscle = JSON.parse(response.body).find { |we| we["exercise"]["id"] == exercises(:provider_situp).id }["exercise"]["primary_muscle"]

    get "/api/v1/coach/workouts/#{workout.id}/workout_exercises",
      headers: auth_headers_for(@coach).merge("Accept-Language" => "it")
    it_muscle = JSON.parse(response.body).find { |we| we["exercise"]["id"] == exercises(:provider_situp).id }["exercise"]["primary_muscle"]

    assert_equal "abs", en_muscle["key"]
    assert_equal "abs", it_muscle["key"], "the filter value must never change with locale"
    assert_equal "Abs", en_muscle["name"]
    assert_equal "Addominali", it_muscle["name"]
  end
end
