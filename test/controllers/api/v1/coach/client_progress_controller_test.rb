require "test_helper"

class Api::V1::Coach::ClientProgressControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @session = workout_sessions(:alice_chest_session)
  end

  # GET index
  test "index returns client's workout sessions" do
    get "/api/v1/coach/clients/#{@client.id}/progress", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |s| s["id"] == @session.id }
  end

  test "index returns 404 for non-owned client" do
    other_client = User.create!(name: "Other", email: "other_progress@example.com", role: "client")
    get "/api/v1/coach/clients/#{other_client.id}/progress", headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  test "index returns 403 for client role" do
    get "/api/v1/coach/clients/#{@client.id}/progress", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET show
  test "show returns session with exercise logs" do
    get "/api/v1/coach/clients/#{@client.id}/progress/#{@session.id}", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("exercise_logs")
  end

  test "show returns 404 for session not belonging to client" do
    get "/api/v1/coach/clients/#{@client.id}/progress/0", headers: auth_headers_for(@coach)
    assert_response :not_found
  end
end
