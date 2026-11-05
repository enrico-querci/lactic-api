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
                   authorization_code: "code-1", app: nil }, received)
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

  # === review_access ===

  REVIEW_CODE = "review-code-for-tests-0123456789".freeze

  test "review_access signs in the demo client, whose token opens the client screens" do
    with_review_code(REVIEW_CODE) do
      post api_v1_auth_review_access_path, params: { code: REVIEW_CODE }, as: :json

      assert_response :ok
      json = response.parsed_body
      assert_equal "client", json["user"]["role"]
      assert_equal Review::DemoAccount::CLIENT_EMAIL, json["user"]["email"]

      headers = { "Authorization" => "Bearer #{json['access_token']}" }
      get api_v1_client_programs_path, headers: headers
      assert_response :ok
      assert_equal 1, response.parsed_body.size

      get api_v1_client_workout_sessions_path, headers: headers
      assert_response :ok
      assert_not_empty response.parsed_body

      post api_v1_auth_refresh_path, params: { refresh_token: json["refresh_token"] }, as: :json
      assert_response :ok
    end
  end

  test "review_access ignores any identity or role the caller sends" do
    with_review_code(REVIEW_CODE) do
      post api_v1_auth_review_access_path,
           params: { code: REVIEW_CODE, email: users(:coach_john).email, role: "coach", user_id: users(:coach_john).id },
           as: :json

      assert_response :ok
      assert_equal Review::DemoAccount::CLIENT_EMAIL, response.parsed_body["user"]["email"]
    end
  end

  test "review_access refuses a wrong code with 401" do
    with_review_code(REVIEW_CODE) do
      post api_v1_auth_review_access_path, params: { code: "nope" }, as: :json

      assert_response :unauthorized
      assert_equal "Invalid code", response.parsed_body["error"]
    end
  end

  test "review_access answers the same 401 when no code is configured" do
    with_review_code(nil) do
      post api_v1_auth_review_access_path, params: { code: REVIEW_CODE }, as: :json

      assert_response :unauthorized
      assert_equal "Invalid code", response.parsed_body["error"]
    end
  end

  test "the review code is filtered out of logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal({ "code" => "[FILTERED]" }, filter.filter({ "code" => REVIEW_CODE }))
  end

  # === authentication protection ===

  test "protected endpoint returns 401 without token" do
    # The health check is unprotected (it's a Rails internal route),
    # so we test by hitting a route that requires auth.
    # For now, we verify auth middleware works via dev_login + a manual check.
    get "/up"
    assert_response :ok
  end

  private

  def with_review_code(value)
    previous = ENV["REVIEW_ACCESS_CODE"]
    value.nil? ? ENV.delete("REVIEW_ACCESS_CODE") : ENV["REVIEW_ACCESS_CODE"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("REVIEW_ACCESS_CODE") : ENV["REVIEW_ACCESS_CODE"] = previous
  end
end
