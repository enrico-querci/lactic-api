require "test_helper"

class JwtServiceTest < ActiveSupport::TestCase
  test "encode returns a string token" do
    token = JwtService.encode(user_id: 1)
    assert_kind_of String, token
    assert token.split(".").length == 3, "JWT should have 3 parts"
  end

  test "decode returns payload with user_id" do
    token = JwtService.encode(user_id: 42)
    payload = JwtService.decode(token)
    assert_equal 42, payload["user_id"]
  end

  test "decode includes exp claim" do
    token = JwtService.encode(user_id: 1)
    payload = JwtService.decode(token)
    assert payload["exp"].present?
    assert payload["exp"] > Time.current.to_i
  end

  test "decode raises on expired token" do
    token = JwtService.encode(user_id: 1, expires_in: -1.second)
    assert_raises(JWT::ExpiredSignature) do
      JwtService.decode(token)
    end
  end

  test "decode raises on tampered token" do
    token = JwtService.encode(user_id: 1)
    tampered = token + "tampered"
    assert_raises(JWT::DecodeError) do
      JwtService.decode(tampered)
    end
  end

  test "decode raises on nil token" do
    assert_raises(JWT::DecodeError) do
      JwtService.decode(nil)
    end
  end
end
