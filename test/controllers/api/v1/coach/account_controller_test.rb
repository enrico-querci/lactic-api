require "test_helper"

class Api::V1::Coach::AccountControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
  end

  test "destroy deletes the coach and everything they own, keeping their clients" do
    program_ids = @coach.programs.pluck(:id)
    assert program_ids.any?, "fixtures should give the coach programs to cascade through"

    assert_difference "User.count", -1 do
      delete "/api/v1/coach/account", headers: auth_headers_for(@coach)
    end

    assert_response :no_content
    assert_not User.exists?(@coach.id)
    assert_not Program.where(id: program_ids).exists?
    assert_not ProgramAssignment.where(coach_id: @coach.id).exists?
    assert_not ClientInvitation.where(coach_id: @coach.id).exists?
    # Clients are their own accounts: they stay, with no coach.
    assert_nil @client.reload.coach_id
  end

  test "destroy revokes the Sign in with Apple token before deleting" do
    @coach.update!(apple_refresh_token: "r-1", apple_client_id: "com.enricoquerci.lacticstudio")
    revoked = []
    original = Auth::AppleAuthorization.method(:revoke)
    Auth::AppleAuthorization.define_singleton_method(:revoke) { |user| revoked << [ user.id, User.exists?(user.id) ] }

    delete "/api/v1/coach/account", headers: auth_headers_for(@coach)

    assert_response :no_content
    assert_equal [ [ @coach.id, true ] ], revoked
  ensure
    Auth::AppleAuthorization.define_singleton_method(:revoke, original)
  end

  test "destroy is refused while a paid plan will still renew" do
    CoachSubscription.create!(user: @coach, plan_key: "pro", environment: "PRODUCTION",
                              expires_at: 1.month.from_now, auto_renew: true)

    assert_no_difference "User.count" do
      delete "/api/v1/coach/account", headers: auth_headers_for(@coach)
    end

    assert_response :conflict
    assert_equal "subscription_active", response.parsed_body["code"]
  end

  test "destroy goes ahead once the subscription is cancelled, even before it lapses" do
    CoachSubscription.create!(user: @coach, plan_key: "pro", environment: "PRODUCTION",
                              expires_at: 1.month.from_now, auto_renew: false)

    delete "/api/v1/coach/account", headers: auth_headers_for(@coach)

    assert_response :no_content
    assert_not User.exists?(@coach.id)
  end

  test "destroy returns 403 for a client" do
    delete "/api/v1/coach/account", headers: auth_headers_for(@client)

    assert_response :forbidden
    assert User.exists?(@client.id)
  end

  test "destroy returns 401 without auth headers" do
    delete "/api/v1/coach/account"

    assert_response :unauthorized
  end
end
