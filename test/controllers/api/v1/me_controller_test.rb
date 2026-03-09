require "test_helper"

class Api::V1::MeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
  end

  # GET /api/v1/me
  test "show returns current user profile" do
    get "/api/v1/me", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @coach.id, json["id"]
    assert_equal @coach.name, json["name"]
    assert_equal @coach.email, json["email"]
    assert_equal "coach", json["role"]
  end

  test "show returns 401 without token" do
    get "/api/v1/me"
    assert_response :unauthorized
  end

  # PATCH /api/v1/me
  test "update changes name" do
    patch "/api/v1/me", params: { user: { name: "New Name" } }, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "New Name", json["name"]
    assert_equal "New Name", @coach.reload.name
  end

  test "update changes avatar_url" do
    patch "/api/v1/me", params: { user: { avatar_url: "https://example.com/avatar.jpg" } }, headers: auth_headers_for(@client)
    assert_response :ok
    assert_equal "https://example.com/avatar.jpg", @client.reload.avatar_url
  end

  test "update returns 422 for invalid data" do
    patch "/api/v1/me", params: { user: { name: "" } }, headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  test "update returns 401 without token" do
    patch "/api/v1/me", params: { user: { name: "Hacker" } }
    assert_response :unauthorized
  end
end
