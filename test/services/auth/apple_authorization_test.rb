require "test_helper"

class Auth::AppleAuthorizationTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls

    def initialize(configured: true, fail_with: nil)
      @configured = configured
      @fail_with = fail_with
      @calls = []
    end

    def configured? = @configured

    def exchange(code:, client_id:)
      @calls << [ :exchange, code, client_id ]
      raise @fail_with if @fail_with

      "refresh-for-#{code}"
    end

    def revoke(refresh_token:, client_id:)
      @calls << [ :revoke, refresh_token, client_id ]
      raise @fail_with if @fail_with

      true
    end
  end

  setup do
    @user = users(:client_alice)
  end

  test "remember stores the refresh token and the client it belongs to" do
    client = FakeClient.new

    Auth::AppleAuthorization.remember(user: @user, code: "code-1", client_id: "com.enricoquerci.lactic", client: client)

    @user.reload
    assert_equal "refresh-for-code-1", @user.apple_refresh_token
    assert_equal "com.enricoquerci.lactic", @user.apple_client_id
  end

  test "remember does nothing without a code or without configuration" do
    unconfigured = FakeClient.new(configured: false)
    Auth::AppleAuthorization.remember(user: @user, code: "code-1", client_id: "com.enricoquerci.lactic", client: unconfigured)

    no_code = FakeClient.new
    Auth::AppleAuthorization.remember(user: @user, code: nil, client_id: "com.enricoquerci.lactic", client: no_code)

    assert_empty unconfigured.calls
    assert_empty no_code.calls
    assert_nil @user.reload.apple_refresh_token
  end

  test "a failed exchange never fails the sign-in around it" do
    client = FakeClient.new(fail_with: Auth::AppleTokenClient::Error.new("invalid_client"))

    assert_nothing_raised do
      Auth::AppleAuthorization.remember(user: @user, code: "code-1", client_id: "com.enricoquerci.lactic", client: client)
    end
    assert_nil @user.reload.apple_refresh_token
  end

  test "revoke sends the stored token to the client it was issued to" do
    @user.update!(apple_refresh_token: "r-1", apple_client_id: "com.enricoquerci.lactic")
    client = FakeClient.new

    Auth::AppleAuthorization.revoke(@user, client: client)

    assert_equal [ [ :revoke, "r-1", "com.enricoquerci.lactic" ] ], client.calls
  end

  test "revoke skips an account that never used Sign in with Apple" do
    client = FakeClient.new

    Auth::AppleAuthorization.revoke(@user, client: client)

    assert_empty client.calls
  end

  test "a failed revocation never blocks the deletion around it" do
    @user.update!(apple_refresh_token: "r-1", apple_client_id: "com.enricoquerci.lactic")
    client = FakeClient.new(fail_with: Auth::AppleTokenClient::Error.new("network failure"))

    assert_nothing_raised { Auth::AppleAuthorization.revoke(@user, client: client) }
  end
end
