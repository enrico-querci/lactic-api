require "test_helper"

class Api::V1::Client::ExerciseLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @session = workout_sessions(:alice_chest_session)
    @we = workout_exercises(:bench_in_chest_day)
    @log = exercise_logs(:alice_bench_log)
  end

  # POST create
  test "create adds an exercise log" do
    curl_we = workout_exercises(:curl_in_chest_day)
    assert_difference "ExerciseLog.count", 1 do
      post "/api/v1/client/exercise_logs",
           params: { exercise_log: {
             workout_session_id: @session.id,
             workout_exercise_id: curl_we.id,
             notes: "Good form"
           } },
           headers: auth_headers_for(@client)
    end
    assert_response :created
  end

  test "create returns 404 for other client's session" do
    bob = users(:client_bob)
    post "/api/v1/client/exercise_logs",
         params: { exercise_log: {
           workout_session_id: @session.id,
           workout_exercise_id: @we.id
         } },
         headers: auth_headers_for(bob)
    assert_response :not_found
  end

  test "create returns 403 for coach" do
    post "/api/v1/client/exercise_logs",
         params: { exercise_log: {
           workout_session_id: @session.id,
           workout_exercise_id: @we.id
         } },
         headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  # PATCH update
  test "update modifies exercise log notes" do
    patch "/api/v1/client/exercise_logs/#{@log.id}",
          params: { exercise_log: { notes: "Updated notes" } },
          headers: auth_headers_for(@client)
    assert_response :ok
    assert_equal "Updated notes", @log.reload.notes
  end

  test "update returns 404 for other client's log" do
    bob = users(:client_bob)
    patch "/api/v1/client/exercise_logs/#{@log.id}",
          params: { exercise_log: { notes: "Hacked" } },
          headers: auth_headers_for(bob)
    assert_response :not_found
  end
end
