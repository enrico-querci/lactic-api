require "test_helper"

class Api::V1::Client::WorkoutSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @session = workout_sessions(:alice_chest_session)
    @workout = workouts(:chest_day)
    @assignment = program_assignments(:alice_strength)
  end

  # GET index
  test "index returns client's sessions" do
    get "/api/v1/client/workout_sessions", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |s| s["id"] == @session.id }
  end

  test "index returns 403 for coach" do
    get "/api/v1/client/workout_sessions", headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  # GET show
  test "show returns session with exercise logs" do
    get "/api/v1/client/workout_sessions/#{@session.id}", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("exercise_logs")
  end

  test "show returns 404 for other client's session" do
    bob = users(:client_bob)
    get "/api/v1/client/workout_sessions/#{@session.id}", headers: auth_headers_for(bob)
    assert_response :not_found
  end

  # POST create
  test "create starts a workout session" do
    assert_difference "WorkoutSession.count", 1 do
      post "/api/v1/client/workout_sessions",
           params: { workout_session: {
             workout_id: @workout.id,
             program_assignment_id: @assignment.id,
             started_at: "2026-03-09T10:00:00Z"
           } },
           headers: auth_headers_for(@client)
    end
    assert_response :created
  end

  # PATCH update
  test "update completes a session" do
    session = @client.workout_sessions.create!(
      workout: @workout, program_assignment: @assignment,
      started_at: "2026-03-09T10:00:00Z"
    )
    patch "/api/v1/client/workout_sessions/#{session.id}",
          params: { workout_session: { completed_at: "2026-03-09T11:00:00Z", notes: "Done!" } },
          headers: auth_headers_for(@client)
    assert_response :ok
    assert_equal "Done!", session.reload.notes
  end
end
