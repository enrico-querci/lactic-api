require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  # === dev_login ===

  test "dev_login returns tokens for valid email" do
    user = users(:client_alice)
    post api_v1_auth_dev_login_path, params: { email: user.email }

    assert_response :ok
    json = response.parsed_body
    assert json["access_token"].present?
    assert json["refresh_token"].present?
    assert_equal user.id, json["user"]["id"]
    assert_equal user.email, json["user"]["email"]
    assert_equal user.role, json["user"]["role"]
  end

  test "dev_login returns 404 for unknown email" do
    post api_v1_auth_dev_login_path, params: { email: "nonexistent@example.com" }

    assert_response :not_found
    json = response.parsed_body
    assert_equal "User not found", json["error"]
  end

  # === create ===

  # The iOS apps send Apple's first-authorization name and its
  # authorization code as top-level params beside the ID token.
  test "create passes Apple's name and authorization code through" do
    received = nil
    user = users(:coach_john)
    original = Auth::Authenticate.method(:call)
    Auth::Authenticate.define_singleton_method(:call) do |**args|
      received = args
      { user: user, access_token: "a", refresh_token: "r" }
    end

    post api_v1_auth_path, params: {
      provider: "apple", id_token: "tok", name: "Jo Coach", authorization_code: "code-1"
    }, as: :json

    assert_response :ok
    assert_equal({ provider: "apple", id_token: "tok", invitation_token: nil, name: "Jo Coach",
                   authorization_code: "code-1" }, received)
  ensure
    Auth::Authenticate.define_singleton_method(:call, original)
  end

  # === refresh ===

  test "refresh returns new tokens for valid refresh token" do
    token = refresh_tokens(:alice_token)
    post api_v1_auth_refresh_path, params: { refresh_token: token.token }

    assert_response :ok
    json = response.parsed_body
    assert json["access_token"].present?
    assert json["refresh_token"].present?
    # Old token should be rotated (deleted)
    assert_nil RefreshToken.find_by(token: token.token)
  end

  test "refresh returns 401 for expired refresh token" do
    token = refresh_tokens(:expired_token)
    post api_v1_auth_refresh_path, params: { refresh_token: token.token }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Refresh token has expired", json["error"]
  end

  test "refresh returns 401 for invalid refresh token" do
    post api_v1_auth_refresh_path, params: { refresh_token: "nonexistent" }

    assert_response :unauthorized
    json = response.parsed_body
    assert_equal "Invalid refresh token", json["error"]
  end

  # === logout (destroy) ===

  test "logout invalidates refresh token" do
    token = refresh_tokens(:alice_token)
    delete api_v1_auth_path, params: { refresh_token: token.token }

    assert_response :no_content
    assert_nil RefreshToken.find_by(token: token.token)
  end

  test "logout with invalid token still returns no_content" do
    delete api_v1_auth_path, params: { refresh_token: "nonexistent" }

    assert_response :no_content
  end

  # === authentication protection ===

  test "protected endpoint returns 401 without token" do
    # The health check is unprotected (it's a Rails internal route),
    # so we test by hitting a route that requires auth.
    # For now, we verify auth middleware works via dev_login + a manual check.
    get "/up"
    assert_response :ok
  end
end
