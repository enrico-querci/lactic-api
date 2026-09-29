require "test_helper"

# Signs real tokens with a throwaway key and stands in for Apple's key set,
# so the whole verification path runs — decoding, signature, issuer,
# audience, expiry. Stubbing AppleVerifier.verify, as the Authenticate tests
# do, is how a verifier that could never succeed went unnoticed.
class Auth::AppleVerifierTest < ActiveSupport::TestCase
  APPLE_KEY = OpenSSL::PKey::RSA.generate(2048)

  setup do
    @original_fetch = AppleID::JWKS.method(:fetch)
    public_key = JSON::JWK.new(APPLE_KEY.public_key)
    AppleID::JWKS.define_singleton_method(:fetch) { |_kid, *| public_key }
  end

  teardown do
    AppleID::JWKS.define_singleton_method(:fetch, @original_fetch)
  end

  test "verifies a token issued to the client app" do
    identity = Auth::AppleVerifier.verify(apple_token)

    assert_equal "alice@example.com", identity[:email]
    assert_equal "001234.apple-user", identity[:provider_uid]
    assert_equal "com.enricoquerci.lactic", identity[:client_id]
    assert_equal "alice", identity[:name]
  end

  test "verifies a token issued to Lactic Studio" do
    identity = Auth::AppleVerifier.verify(apple_token(aud: "com.enricoquerci.lacticstudio"))

    assert_equal "com.enricoquerci.lacticstudio", identity[:client_id]
  end

  test "rejects a token issued to another app" do
    error = assert_raises(Auth::VerificationError) do
      Auth::AppleVerifier.verify(apple_token(aud: "com.example.someone-else"))
    end
    assert_match "unexpected audience", error.message
  end

  test "rejects a token signed by a key Apple did not publish" do
    forged = apple_token(key: OpenSSL::PKey::RSA.generate(2048))

    assert_raises(Auth::VerificationError) { Auth::AppleVerifier.verify(forged) }
  end

  test "rejects an expired token" do
    expired = apple_token(iat: 2.hours.ago.to_i, exp: 1.hour.ago.to_i)

    assert_raises(Auth::VerificationError) { Auth::AppleVerifier.verify(expired) }
  end

  test "rejects a token from another issuer" do
    assert_raises(Auth::VerificationError) do
      Auth::AppleVerifier.verify(apple_token(iss: "https://accounts.google.com"))
    end
  end

  test "rejects an unverified email, which could otherwise link to someone else's account" do
    error = assert_raises(Auth::VerificationError) do
      Auth::AppleVerifier.verify(apple_token(email_verified: "false"))
    end
    assert_match "verify this email", error.message
  end

  test "rejects a token with no email" do
    assert_raises(Auth::VerificationError) do
      Auth::AppleVerifier.verify(apple_token(email: nil))
    end
  end

  test "rejects garbage" do
    assert_raises(Auth::VerificationError) { Auth::AppleVerifier.verify("not-a-jwt") }
  end

  test "APPLE_CLIENT_IDS replaces the default audiences" do
    with_env("APPLE_CLIENT_IDS" => "com.example.web, com.enricoquerci.lactic") do
      assert_equal %w[com.example.web com.enricoquerci.lactic], Auth::AppleVerifier.client_ids
      assert Auth::AppleVerifier.verify(apple_token(aud: "com.example.web"))
    end
  end

  private

  def apple_token(key: APPLE_KEY, **claims)
    payload = {
      iss: "https://appleid.apple.com",
      aud: "com.enricoquerci.lactic",
      sub: "001234.apple-user",
      iat: Time.now.to_i,
      exp: 10.minutes.from_now.to_i,
      email: "alice@example.com",
      email_verified: "true",
      nonce_supported: true
    }.merge(claims).compact
    jwt = JSON::JWT.new(payload)
    jwt.kid = "test-key"
    jwt.sign(key, :RS256).to_s
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
