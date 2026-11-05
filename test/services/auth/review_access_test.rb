require "test_helper"

class Auth::ReviewAccessTest < ActiveSupport::TestCase
  CODE = "review-code-for-tests-0123456789".freeze

  test "a correct code signs in the demo client" do
    with_review_code(CODE) do
      result = Auth::ReviewAccess.call(code: CODE)

      assert_equal Review::DemoAccount::CLIENT_EMAIL, result[:user].email
      assert result[:user].client?
      assert_equal result[:user].id, JwtService.decode(result[:access_token])["user_id"]
      assert_equal result[:user], RefreshToken.find_by!(token: result[:refresh_token]).user
    end
  end

  test "a wrong code is refused and creates nothing" do
    with_review_code(CODE) do
      assert_no_difference [ "User.count", "RefreshToken.count" ] do
        assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: "#{CODE}x") }
        assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: "") }
        assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: nil) }
      end
    end
  end

  test "is off while no code is configured" do
    with_review_code(nil) do
      assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: "") }
      assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: nil) }
      assert_equal 0, User.where(email: Review::DemoAccount::CLIENT_EMAIL).count
    end
  end

  test "a configured code that is too short does not count as configured" do
    short = "a" * (Auth::ReviewAccess::MIN_CODE_LENGTH - 1)

    with_review_code(short) do
      assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: short) }
    end
  end

  test "reports a broken review account only to someone holding the code" do
    Exercise.update_all(active: false)

    with_review_code(CODE) do
      error = assert_raises(Auth::VerificationError) { Auth::ReviewAccess.call(code: CODE) }
      assert_match(/not available/, error.message)
    end
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
