module Auth
  class Refresh
    def self.call(refresh_token:)
      record = RefreshToken.find_by(token: refresh_token)
      raise Auth::TokenError, "Invalid refresh token" unless record
      raise Auth::TokenError, "Refresh token has expired" if record.expired?

      # Rotate: delete old, create new
      user = record.user
      record.destroy!

      new_access_token = JwtService.encode(user_id: user.id)
      new_refresh_token = user.refresh_tokens.create!(
        token: SecureRandom.hex(32),
        expires_at: JwtService::REFRESH_TOKEN_EXPIRY.from_now
      )

      { access_token: new_access_token, refresh_token: new_refresh_token.token }
    end
  end
end
