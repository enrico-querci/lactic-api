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

  # POST create
  test "create saves a workout as template" do
    assert_difference "WorkoutTemplate.count", 1 do
      post "/api/v1/coach/workout_templates",
           params: { name: "New Template", source_workout_id: @workout.id },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
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
end
