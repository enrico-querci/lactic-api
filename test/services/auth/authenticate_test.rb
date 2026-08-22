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
    invitation = ClientInvitation.create!(coach: users(:coach_john), email: identity[:email])

    stub_google_verifier(**identity) do
      assert_difference "User.count", 1 do
        result = Auth::Authenticate.call(
          provider: "google",
          id_token: "fake_token",
          invitation_token: invitation.raw_token
        )

        assert_equal "newuser@example.com", result[:user].email
        assert_equal "New User", result[:user].name
        assert result[:user].client?
        assert_equal "google", result[:user].provider
        assert_equal "new_uid_456", result[:user].provider_uid
        assert_equal users(:coach_john), result[:user].coach
        assert invitation.reload.accepted_at.present?
      end
    end
  end

  test "an unrecognized email with no invitation becomes a coach" do
    stub_google_verifier(email: "brandnew@example.com", name: "Brand New", provider_uid: "brand_new_uid", avatar_url: nil) do
      result = Auth::Authenticate.call(provider: "google", id_token: "fake_token")

      assert result[:user].coach?
    end
  end

  test "coach signup does not depend on the COACH_EMAILS allowlist" do
    identity = { email: "notlisted@example.com", name: "Not Listed", provider_uid: "not_listed_uid", avatar_url: nil }

    stub_coach_access(allowed: false) do
      stub_google_verifier(**identity) do
        result = Auth::Authenticate.call(provider: "google", id_token: "fake_token")

        assert result[:user].coach?
      end
    end
  end

  test "an invited client who signs in without their invitation link is not silently made a coach" do
    ClientInvitation.create!(coach: users(:coach_john), email: "waiting-client@example.com")

    stub_google_verifier(email: "waiting-client@example.com", name: "Waiting Client", provider_uid: "waiting_uid", avatar_url: nil) do
      error = assert_raises(Auth::VerificationError) do
        Auth::Authenticate.call(provider: "google", id_token: "fake_token")
      end

      assert_equal "Open your invitation link to join your coach", error.message
    end
  end

  test "an expired pending invitation does not block becoming a coach" do
    ClientInvitation.create!(coach: users(:coach_john), email: "expired-invite@example.com")
                    .update_column(:expires_at, 1.day.ago)

    stub_google_verifier(email: "expired-invite@example.com", name: "Expired Invite", provider_uid: "expired_uid", avatar_url: nil) do
      result = Auth::Authenticate.call(provider: "google", id_token: "fake_token")

      assert result[:user].coach?
    end
  end

  test "generates both access and refresh tokens" do
    invitation = ClientInvitation.create!(coach: users(:coach_john), email: "fresh@example.com")

    stub_apple_verifier(email: "fresh@example.com", name: "Fresh", provider_uid: "uid_fresh") do
      result = Auth::Authenticate.call(
        provider: "apple",
        id_token: "fake_token",
        invitation_token: invitation.raw_token
      )

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

  def stub_coach_access(allowed:)
    original = CoachAccess.method(:allowed?)
    CoachAccess.define_singleton_method(:allowed?) { |_email| allowed }
    yield
  ensure
    CoachAccess.define_singleton_method(:allowed?, original)
  end

  def stub_verifier(klass, identity)
    original = klass.method(:verify)
    klass.define_singleton_method(:verify) { |_token| identity }
    yield
  ensure
    klass.define_singleton_method(:verify, original)
  end
end
