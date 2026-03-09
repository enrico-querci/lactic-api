require "test_helper"

class Api::V1::Coach::WorkoutExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @workout = workouts(:chest_day)
    @we = workout_exercises(:bench_in_chest_day)
    @exercise = exercises(:squat)
  end

  def wes_url
    "/api/v1/coach/workouts/#{@workout.id}/workout_exercises"
  end

  def we_url(we = @we)
    "#{wes_url}/#{we.id}"
  end

  # GET index
  test "index returns workout exercises" do
    get wes_url, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.size >= 2
  end

  test "index returns 403 for client" do
    get wes_url, headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # POST create
  test "create adds a workout exercise" do
    assert_difference "WorkoutExercise.count", 1 do
      post wes_url,
           params: { workout_exercise: { exercise_id: @exercise.id, position: "C", sets: 3, reps: 10 } },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "C", json["position"]
  end

  test "create returns 422 for duplicate position" do
    post wes_url,
         params: { workout_exercise: { exercise_id: @exercise.id, position: "A", sets: 3, reps: 10 } },
         headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  # PATCH update
  test "update modifies sets" do
    patch we_url, params: { workout_exercise: { sets: 5 } }, headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal 5, @we.reload.sets
  end

  # DELETE destroy
  test "destroy removes workout exercise" do
    we = @workout.workout_exercises.create!(exercise: @exercise, position: "D", sets: 3, reps: 10)
    assert_difference "WorkoutExercise.count", -1 do
      delete we_url(we), headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end
end
