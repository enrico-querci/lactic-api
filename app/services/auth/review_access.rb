module Auth
  # Signs a reviewer into the demo client with a code, with no Google or Apple
  # identity. App Review has no account of ours to sign in with and cannot be
  # expected to create one, so the app offers this beside the invitation code.
  #
  # It is a way in that skips social sign-in, so it is deliberately narrow:
  #
  # * Off unless REVIEW_ACCESS_CODE is set, and a code shorter than
  #   MIN_CODE_LENGTH counts as not set. Removing the variable closes it.
  # * It signs in one fixed account (Review::DemoAccount) and never creates a
  #   user, accepts a role or reads anything the caller sends beyond the code.
  # * It never touches invitations: the social-email match that protects them
  #   is unchanged.
  #
  # A wrong code, an unset one and a too-short one are indistinguishable from
  # outside, so the endpoint does not reveal whether it is switched on.
  class ReviewAccess
    MIN_CODE_LENGTH = 16

    def self.call(code:)
      raise Auth::VerificationError, "Invalid code" unless valid_code?(code)

      user = Review::DemoAccount.ensure!
      issue_tokens(user)
    rescue Review::DemoAccount::SetupError => e
      # Only reachable with the right code, so the reason is safe to give.
      Rails.error.report(e, handled: true)
      raise Auth::VerificationError, "The review account is not available right now"
    end

    def self.valid_code?(code)
      expected = ENV["REVIEW_ACCESS_CODE"].to_s
      return false if expected.length < MIN_CODE_LENGTH

      # Compare digests so neither the length nor the content of the real
      # code can be learned from how long a wrong guess takes.
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(code.to_s), Digest::SHA256.hexdigest(expected)
      )
    end
    private_class_method :valid_code?

    def self.issue_tokens(user)
      refresh_token = user.refresh_tokens.create!(
        token: SecureRandom.hex(32),
        expires_at: JwtService::REFRESH_TOKEN_EXPIRY.from_now
      )
      { user: user, access_token: JwtService.encode(user_id: user.id), refresh_token: refresh_token.token }
    end
    private_class_method :issue_tokens
  end
end
