require "test_helper"

class Api::V1::Coach::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
  end

  test "show returns the summary" do
    get "/api/v1/coach/dashboard", headers: auth_headers_for(@coach)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal %w[attention attention_total clients inactive_clients pending_invitations recent_activity sessions], json.keys.sort
    assert_equal 2, json["clients"]["active"]
    assert_equal %w[active limit slots_used], json["clients"].keys.sort
    assert_equal %w[last_week this_week], json["sessions"].keys.sort
    assert_kind_of Array, json["attention"]
  end

  test "the attention items carry what the web needs to link them" do
    get "/api/v1/coach/dashboard", headers: auth_headers_for(@coach)
    item = JSON.parse(response.body)["attention"].find { |entry| entry["name"] == "Bob Client" }

    assert_equal "no_program", item["kind"]
    assert_equal users(:client_bob).id, item["client_id"]
    assert_equal client_profiles(:bob_profile).id, item["profile_id"]
  end

  test "show returns 403 for a client" do
    get "/api/v1/coach/dashboard", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  test "show returns 401 without a token" do
    get "/api/v1/coach/dashboard"
    assert_response :unauthorized
  end
end
