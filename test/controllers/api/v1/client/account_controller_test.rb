require "test_helper"

class Api::V1::Client::AccountControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @bob = users(:client_bob)
  end

  test "destroy permanently deletes the client and cascades" do
    client_id = @client.id
    assignment_id = program_assignments(:alice_strength).id
    session_id = workout_sessions(:alice_chest_session).id
    log_id = exercise_logs(:alice_bench_log).id
    set_id = set_logs(:bench_set_one).id
    token_id = refresh_tokens(:alice_token).id

    assert_difference "User.count", -1 do
      delete "/api/v1/client/account", headers: auth_headers_for(@client)
    end
    assert_response :no_content

    assert_not User.exists?(client_id)
    assert_not ProgramAssignment.exists?(assignment_id)
    assert_not WorkoutSession.exists?(session_id)
    assert_not ExerciseLog.exists?(log_id)
    assert_not SetLog.exists?(set_id)
    assert_not RefreshToken.exists?(token_id)
  end

  test "destroy does not touch the coach or other clients' data" do
    delete "/api/v1/client/account", headers: auth_headers_for(@client)
    assert_response :no_content

    assert User.exists?(@coach.id)
    assert User.exists?(@bob.id)
    assert RefreshToken.exists?(refresh_tokens(:expired_token).id) # bob's token
  end

  # App Review guideline 5.1.1(v): deleting an account that used Sign in
  # with Apple must revoke its token.
  test "destroy revokes the Sign in with Apple token before deleting" do
    @client.update!(apple_refresh_token: "r-1", apple_client_id: "com.enricoquerci.lactic")
    revoked = []
    original = Auth::AppleAuthorization.method(:revoke)
    Auth::AppleAuthorization.define_singleton_method(:revoke) do |user|
      revoked << [ user.id, user.apple_refresh_token, User.exists?(user.id) ]
    end

    delete "/api/v1/client/account", headers: auth_headers_for(@client)

    assert_response :no_content
    assert_equal [ [ @client.id, "r-1", true ] ], revoked
    assert_not User.exists?(@client.id)
  ensure
    Auth::AppleAuthorization.define_singleton_method(:revoke, original)
  end

  test "destroy returns 403 for coach role" do
    delete "/api/v1/client/account", headers: auth_headers_for(@coach)
    assert_response :forbidden
    assert User.exists?(@coach.id)
  end

  test "destroy returns 401 without auth headers" do
    delete "/api/v1/client/account"
    assert_response :unauthorized
  end
end
