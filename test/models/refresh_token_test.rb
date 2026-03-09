require "test_helper"

class RefreshTokenTest < ActiveSupport::TestCase
  test "valid refresh token" do
    token = refresh_tokens(:alice_token)
    assert token.valid?
  end

  test "requires token" do
    rt = RefreshToken.new(user: users(:client_alice), expires_at: 1.day.from_now)
    assert_not rt.valid?
    assert_includes rt.errors[:token], "can't be blank"
  end

  test "requires unique token" do
    rt = RefreshToken.new(
      user: users(:client_alice),
      token: refresh_tokens(:alice_token).token,
      expires_at: 1.day.from_now
    )
    assert_not rt.valid?
    assert_includes rt.errors[:token], "has already been taken"
  end

  test "requires expires_at" do
    rt = RefreshToken.new(user: users(:client_alice), token: "unique_token_123")
    assert_not rt.valid?
    assert_includes rt.errors[:expires_at], "can't be blank"
  end

  test "expired? returns true for past expiry" do
    token = refresh_tokens(:expired_token)
    assert token.expired?
  end

  test "expired? returns false for future expiry" do
    token = refresh_tokens(:alice_token)
    assert_not token.expired?
  end

  test "active scope excludes expired tokens" do
    active = RefreshToken.active
    assert_includes active, refresh_tokens(:alice_token)
    assert_not_includes active, refresh_tokens(:expired_token)
  end

  test "belongs to user" do
    token = refresh_tokens(:alice_token)
    assert_equal users(:client_alice), token.user
  end
end
