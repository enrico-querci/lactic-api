require "test_helper"

class Api::V1::Client::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @bench = exercises(:bench_press)
  end

  # GET index
  test "index returns catalog and coach's custom exercises" do
    get "/api/v1/client/exercises", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.size >= 4
  end

  test "index filters by muscle_group" do
    get "/api/v1/client/exercises", params: { muscle_group: "Chest" }, headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    json.each { |e| assert_equal "Chest", e["muscle_group"] }
  end

  test "index returns 403 for coach" do
    get "/api/v1/client/exercises", headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  # GET show
  test "show returns an exercise" do
    get "/api/v1/client/exercises/#{@bench.id}", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @bench.name, json["name"]
  end

  # GET history
  test "history returns set logs for exercise" do
    get "/api/v1/client/exercises/#{@bench.id}/history", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.size >= 2
  end

  test "history returns empty for exercise with no logs" do
    squat = exercises(:squat)
    get "/api/v1/client/exercises/#{squat.id}/history", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 0, json.size
  end
end
