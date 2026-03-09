require "test_helper"

class Api::V1::Client::WorkoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @workout = workouts(:chest_day)
  end

  # GET show
  test "show returns workout with exercises" do
    get "/api/v1/client/workouts/#{@workout.id}", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @workout.name, json["name"]
    assert json.key?("workout_exercises")
  end

  test "show returns 403 for coach" do
    get "/api/v1/client/workouts/#{@workout.id}", headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  test "show returns 404 for unassigned workout" do
    other_coach = User.create!(name: "OtherC", email: "other_wc@example.com", role: "coach")
    other_program = Program.create!(name: "Other", coach: other_coach)
    other_week = other_program.weeks.create!(position: 1)
    other_workout = other_week.workouts.create!(name: "Other", day: 1)
    get "/api/v1/client/workouts/#{other_workout.id}", headers: auth_headers_for(@client)
    assert_response :not_found
  end
end
