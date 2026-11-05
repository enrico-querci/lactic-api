require "test_helper"

class Api::V1::Coach::WorkoutTemplateExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @template = workout_templates(:chest_template)
    @bench = workout_template_exercises(:bench_in_chest_template)
    @squat = exercises(:squat)
  end

  def url(suffix = "")
    "/api/v1/coach/workout_templates/#{@template.id}/workout_exercises#{suffix}"
  end

  def create_params(overrides = {})
    { workout_exercise: { exercise_id: @squat.id, sets: 3, reps: 8, rest_seconds: 120 }.merge(overrides) }
  end

  # GET index
  test "index lists the template's exercises in position order" do
    get url, headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal %w[A B], JSON.parse(response.body).map { |e| e["position"] }
  end

  test "index returns 403 for client" do
    get url, headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  test "index returns 404 for a template that is not the coach's" do
    other = WorkoutTemplate.create!(name: "Not mine", coach: @client)
    get "/api/v1/coach/workout_templates/#{other.id}/workout_exercises", headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # POST create
  test "create adds an exercise at the next free position" do
    assert_difference "@template.workout_template_exercises.count", 1 do
      post url, params: create_params, headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "C", json["position"]
    assert_equal [ 3, 8, 120 ], json.values_at("sets", "reps", "rest_seconds")
    assert_equal @squat.id, json["exercise"]["id"]
  end

  test "create fills a gap left by a removed exercise instead of colliding" do
    @bench.destroy!
    post url, params: create_params, headers: auth_headers_for(@coach)
    assert_response :created
    assert_equal "A", JSON.parse(response.body)["position"]
  end

  test "create honours an explicit position" do
    post url, params: create_params(position: "F"), headers: auth_headers_for(@coach)
    assert_response :created
    assert_equal "F", JSON.parse(response.body)["position"]
  end

  test "create rejects a position that is already taken" do
    assert_no_difference "WorkoutTemplateExercise.count" do
      post url, params: create_params(position: "A"), headers: auth_headers_for(@coach)
    end
    assert_response :unprocessable_entity
  end

  test "create rejects invalid sets" do
    post url, params: create_params(sets: 0), headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  test "create keeps the optional fields" do
    post url, params: create_params(rir: 1, weight: 42.5, notes: "slow"), headers: auth_headers_for(@coach)
    json = JSON.parse(response.body)
    assert_equal [ 1, "slow" ], json.values_at("rir", "notes")
    assert_equal 42.5, json["weight"].to_f
  end

  test "create refuses an exercise the coach could not pick for a workout" do
    foreign = Exercise.create!(name: "Someone else's", is_custom: true, coach: @client,
                               muscle_group: "Chest", prescription_type: "repetitions")

    [ foreign.id, exercises(:provider_treadmill).id, 0 ].each do |exercise_id|
      assert_no_difference "WorkoutTemplateExercise.count" do
        post url, params: create_params(exercise_id: exercise_id), headers: auth_headers_for(@coach)
      end
      assert_response :not_found
    end
  end

  test "create accepts the coach's own custom exercise" do
    post url, params: create_params(exercise_id: exercises(:custom_exercise).id), headers: auth_headers_for(@coach)
    assert_response :created
  end

  test "create is refused once all 26 positions are used" do
    (@template.workout_template_exercises.pluck(:position).size...26).each do
      @template.workout_template_exercises.create!(exercise: @squat, sets: 1, reps: 1)
    end

    assert_no_difference "WorkoutTemplateExercise.count" do
      post url, params: create_params, headers: auth_headers_for(@coach)
    end
    assert_response :unprocessable_entity
  end

  test "create returns 403 for client" do
    post url, params: create_params, headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # PATCH update
  test "update changes the prescription" do
    patch url("/#{@bench.id}"),
          params: { workout_exercise: { sets: 5, reps: 6, weight: 70, rir: 0, notes: "heavy" } },
          headers: auth_headers_for(@coach)
    assert_response :ok
    @bench.reload
    assert_equal [ 5, 6, 0, "heavy" ], [ @bench.sets, @bench.reps, @bench.rir, @bench.notes ]
    assert_equal 70, @bench.weight.to_i
  end

  test "update cannot swap the exercise" do
    patch url("/#{@bench.id}"),
          params: { workout_exercise: { exercise_id: @squat.id, sets: 5 } },
          headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal exercises(:bench_press), @bench.reload.exercise
  end

  test "update rejects invalid values" do
    patch url("/#{@bench.id}"), params: { workout_exercise: { reps: 0 } }, headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  test "update returns 404 for an exercise of another template" do
    other = WorkoutTemplate.create!(name: "Other", coach: @coach)
    other_exercise = other.workout_template_exercises.create!(exercise: @squat, sets: 1, reps: 1)
    patch url("/#{other_exercise.id}"), params: { workout_exercise: { sets: 9 } }, headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # DELETE destroy
  test "destroy removes an exercise from the template only" do
    assert_difference "WorkoutTemplateExercise.count", -1 do
      assert_no_difference [ "WorkoutExercise.count", "Exercise.count" ] do
        delete url("/#{@bench.id}"), headers: auth_headers_for(@coach)
      end
    end
    assert_response :no_content
  end

  test "destroy returns 403 for client" do
    delete url("/#{@bench.id}"), headers: auth_headers_for(@client)
    assert_response :forbidden
  end
end
