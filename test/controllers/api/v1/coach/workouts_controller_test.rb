require "test_helper"

class Api::V1::Coach::WorkoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @program = programs(:strength_program)
    @week = weeks(:week_one)
    @workout = workouts(:chest_day)
  end

  def workouts_url(week = @week)
    "/api/v1/coach/programs/#{@program.id}/weeks/#{week.id}/workouts"
  end

  def workout_url(workout = @workout)
    "#{workouts_url}/#{workout.id}"
  end

  # GET index
  test "index returns workouts for a week" do
    get workouts_url, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json.size
  end

  test "index returns 403 for client" do
    get workouts_url, headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET show
  test "show returns workout with exercises" do
    get workout_url, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @workout.name, json["name"]
    assert json.key?("workout_exercises")
  end

  # POST create
  test "create adds a workout" do
    assert_difference "Workout.count", 1 do
      post workouts_url, params: { workout: { name: "Arm Day", day: 5 } }, headers: auth_headers_for(@coach)
    end
    assert_response :created
  end

  test "create returns 422 for invalid day" do
    post workouts_url, params: { workout: { name: "Bad", day: 9 } }, headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  # PATCH update
  test "update modifies a workout" do
    patch workout_url, params: { workout: { name: "Renamed" } }, headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal "Renamed", @workout.reload.name
  end

  # DELETE destroy
  test "destroy deletes a workout" do
    workout = @week.workouts.create!(name: "Temp", day: 7)
    assert_difference "Workout.count", -1 do
      delete workout_url(workout), headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end

  # POST duplicate
  test "duplicate copies workout to same week" do
    assert_difference "Workout.count", 1 do
      post "#{workout_url}/duplicate", headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal @workout.name, json["name"]
  end

  test "duplicate copies workout to different week" do
    week_two = weeks(:week_two)
    assert_difference "Workout.count", 1 do
      post "#{workout_url}/duplicate", params: { target_week_id: week_two.id, day: 2 }, headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json["day"]
  end
end
