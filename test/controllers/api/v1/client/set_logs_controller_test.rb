require "test_helper"

class Api::V1::Client::SetLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @log = exercise_logs(:alice_bench_log)
    @set = set_logs(:bench_set_one)
  end

  # POST create
  test "create adds a set log" do
    assert_difference "SetLog.count", 1 do
      post "/api/v1/client/set_logs",
           params: { set_log: {
             exercise_log_id: @log.id,
             position: 3,
             weight_kg: 65.0,
             reps: 8
           } },
           headers: auth_headers_for(@client)
    end
    assert_response :created
  end

  test "create returns 404 for other client's exercise log" do
    bob = users(:client_bob)
    post "/api/v1/client/set_logs",
         params: { set_log: {
           exercise_log_id: @log.id,
           position: 3,
           weight_kg: 65.0,
           reps: 8
         } },
         headers: auth_headers_for(bob)
    assert_response :not_found
  end

  test "create returns 422 for invalid data" do
    post "/api/v1/client/set_logs",
         params: { set_log: {
           exercise_log_id: @log.id,
           position: 1,
           weight_kg: -5,
           reps: 0
         } },
         headers: auth_headers_for(@client)
    assert_response :unprocessable_entity
  end

  test "create returns 403 for coach" do
    post "/api/v1/client/set_logs",
         params: { set_log: {
           exercise_log_id: @log.id,
           position: 3,
           weight_kg: 65.0,
           reps: 8
         } },
         headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  # PATCH update
  test "update modifies set log" do
    patch "/api/v1/client/set_logs/#{@set.id}",
          params: { set_log: { weight_kg: 70.0, reps: 6 } },
          headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "70.0", json["weight_kg"]
    assert_equal 6, json["reps"]
  end

  test "update returns 404 for other client's set" do
    bob = users(:client_bob)
    patch "/api/v1/client/set_logs/#{@set.id}",
          params: { set_log: { weight_kg: 999 } },
          headers: auth_headers_for(bob)
    assert_response :not_found
  end

  # DELETE destroy
  test "destroy deletes a set log" do
    set = @log.set_logs.create!(position: 4, weight_kg: 50, reps: 10)
    assert_difference "SetLog.count", -1 do
      delete "/api/v1/client/set_logs/#{set.id}", headers: auth_headers_for(@client)
    end
    assert_response :no_content
  end

  test "destroy returns 404 for other client's set" do
    bob = users(:client_bob)
    delete "/api/v1/client/set_logs/#{@set.id}", headers: auth_headers_for(bob)
    assert_response :not_found
  end
end
