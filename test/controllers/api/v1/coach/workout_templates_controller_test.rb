require "test_helper"

class Api::V1::Coach::WorkoutTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @template = workout_templates(:chest_template)
    @workout = workouts(:chest_day)
    @week_two = weeks(:week_two)
  end

  # GET index
  test "index returns coach's templates" do
    get "/api/v1/coach/workout_templates", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |t| t["id"] == @template.id }
  end

  test "index reports how many exercises each template holds" do
    get "/api/v1/coach/workout_templates", headers: auth_headers_for(@coach)
    json = JSON.parse(response.body)
    assert_equal 2, json.find { |t| t["id"] == @template.id }["exercise_count"]
  end

  test "index returns 403 for client" do
    get "/api/v1/coach/workout_templates", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET show
  test "show returns a template" do
    get "/api/v1/coach/workout_templates/#{@template.id}", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @template.name, json["name"]
  end

  test "show includes the template's exercises in the workout exercise shape" do
    get "/api/v1/coach/workout_templates/#{@template.id}", headers: auth_headers_for(@coach)
    json = JSON.parse(response.body)

    assert_equal %w[A B], json["workout_exercises"].map { |e| e["position"] }
    bench = json["workout_exercises"].first
    assert_equal [ 4, 10, 90, 2 ], bench.values_at("sets", "reps", "rest_seconds", "rir")
    assert_equal exercises(:bench_press).id, bench["exercise"]["id"]
  end

  test "show returns 404 for a template that is not the coach's" do
    other = WorkoutTemplate.create!(name: "Not mine", coach: users(:client_alice))
    get "/api/v1/coach/workout_templates/#{other.id}", headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # POST create
  test "create without a source workout makes an empty template" do
    assert_difference "WorkoutTemplate.count", 1 do
      post "/api/v1/coach/workout_templates",
           params: { name: "Gambe Principiante" },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Gambe Principiante", json["name"]
    assert_equal 0, json["exercise_count"]
    assert_nil json["source_workout_id"]
  end

  test "create without a name or source workout is rejected" do
    assert_no_difference "WorkoutTemplate.count" do
      post "/api/v1/coach/workout_templates", params: { name: "" }, headers: auth_headers_for(@coach)
    end
    assert_response :unprocessable_entity
  end

  test "create saves a workout as template" do
    assert_difference "WorkoutTemplate.count", 1 do
      post "/api/v1/coach/workout_templates",
           params: { name: "New Template", source_workout_id: @workout.id },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
  end

  test "create copies the workout's exercises into the template" do
    assert_difference "WorkoutTemplateExercise.count", @workout.workout_exercises.count do
      post "/api/v1/coach/workout_templates",
           params: { name: "New Template", source_workout_id: @workout.id },
           headers: auth_headers_for(@coach)
    end
    json = JSON.parse(response.body)
    assert_equal @workout.workout_exercises.count, json["exercise_count"]
  end

  test "create without a name saves nothing" do
    assert_no_difference [ "WorkoutTemplate.count", "WorkoutTemplateExercise.count" ] do
      post "/api/v1/coach/workout_templates",
           params: { name: "", source_workout_id: @workout.id },
           headers: auth_headers_for(@coach)
    end
    assert_response :unprocessable_entity
  end

  # PATCH update
  test "update renames a template" do
    patch "/api/v1/coach/workout_templates/#{@template.id}",
          params: { name: "Renamed" },
          headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal "Renamed", @template.reload.name
  end

  test "update rejects a blank name" do
    patch "/api/v1/coach/workout_templates/#{@template.id}",
          params: { name: "" },
          headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
    assert_equal "Chest Day Template", @template.reload.name
  end

  test "update returns 403 for client" do
    patch "/api/v1/coach/workout_templates/#{@template.id}",
          params: { name: "X" },
          headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # DELETE destroy
  test "destroy deletes a template" do
    assert_difference "WorkoutTemplate.count", -1 do
      delete "/api/v1/coach/workout_templates/#{@template.id}", headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end

  # POST apply
  test "apply creates workout from template" do
    assert_difference "Workout.count", 1 do
      post "/api/v1/coach/workout_templates/#{@template.id}/apply",
           params: { target_week_id: @week_two.id, day: 4 },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 4, json["day"]
  end

  test "apply copies the template's exercises and prescription" do
    assert_difference "WorkoutExercise.count", 2 do
      post "/api/v1/coach/workout_templates/#{@template.id}/apply",
           params: { target_week_id: @week_two.id, day: 4 },
           headers: auth_headers_for(@coach)
    end
    workout = Workout.find(JSON.parse(response.body)["id"])
    assert_equal @template.name, workout.name
    assert_equal [ 4, 10, 90, 2 ], workout.workout_exercises.first.then { |we| [ we.sets, we.reps, we.rest_seconds, we.rir ] }
  end

  test "apply can be repeated on several days" do
    assert_difference "Workout.count", 3 do
      [ 1, 3, 5 ].each do |day|
        post "/api/v1/coach/workout_templates/#{@template.id}/apply",
             params: { target_week_id: @week_two.id, day: day },
             headers: auth_headers_for(@coach)
        assert_response :created
      end
    end
  end

  test "apply still works after the workout it was saved from is deleted" do
    @workout.destroy!

    assert_difference "Workout.count", 1 do
      post "/api/v1/coach/workout_templates/#{@template.id}/apply",
           params: { target_week_id: @week_two.id, day: 2 },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
  end
end
