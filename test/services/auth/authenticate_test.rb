require "test_helper"

class Auth::AuthenticateTest < ActiveSupport::TestCase
  test "raises on unsupported provider" do
    assert_raises(Auth::VerificationError) do
      Auth::Authenticate.call(provider: "facebook", id_token: "token")
    end
  end

  test "finds existing user by provider and uid" do
    user = users(:client_alice)
    user.update!(provider: "apple", provider_uid: "apple_uid_123")

    stub_apple_verifier(email: user.email, name: user.name, provider_uid: "apple_uid_123") do
      result = Auth::Authenticate.call(provider: "apple", id_token: "fake_token")

      assert_equal user, result[:user]
      assert result[:access_token].present?
      assert result[:refresh_token].present?
    end
  end

  test "links existing user found by email" do
    user = users(:client_alice)
    assert_nil user.provider

    stub_apple_verifier(email: user.email, name: user.name, provider_uid: "new_apple_uid") do
      result = Auth::Authenticate.call(provider: "apple", id_token: "fake_token")

      assert_equal user, result[:user]
      user.reload
      assert_equal "apple", user.provider
      assert_equal "new_apple_uid", user.provider_uid
    end
  end

  test "creates new user when none exists" do
    identity = { email: "newuser@example.com", name: "New User", provider_uid: "new_uid_456", avatar_url: nil }

    stub_google_verifier(**identity) do
      assert_difference "User.count", 1 do
        result = Auth::Authenticate.call(provider: "google", id_token: "fake_token")

        assert_equal "newuser@example.com", result[:user].email
        assert_equal "New User", result[:user].name
        assert result[:user].client?
        assert_equal "google", result[:user].provider
        assert_equal "new_uid_456", result[:user].provider_uid
      end
    end
  end

  test "generates both access and refresh tokens" do
    stub_apple_verifier(email: "fresh@example.com", name: "Fresh", provider_uid: "uid_fresh") do
      result = Auth::Authenticate.call(provider: "apple", id_token: "fake_token")

      assert result[:access_token].present?
      assert result[:refresh_token].present?
      payload = JwtService.decode(result[:access_token])
      assert_equal result[:user].id, payload["user_id"]
    end
  end

  private

  def stub_apple_verifier(**identity, &block)
    stub_verifier(Auth::AppleVerifier, identity, &block)
  end

  def stub_google_verifier(**identity, &block)
    stub_verifier(Auth::GoogleVerifier, identity, &block)
  end

  def stub_verifier(klass, identity)
    original = klass.method(:verify)
    klass.define_singleton_method(:verify) { |_token| identity }
    yield
  ensure
    klass.define_singleton_method(:verify, original)
  end
end
