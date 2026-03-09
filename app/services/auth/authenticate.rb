module Auth
  class Authenticate
    PROVIDERS = {
      "apple" => Auth::AppleVerifier,
      "google" => Auth::GoogleVerifier
    }.freeze

    def self.call(provider:, id_token:)
      verifier = PROVIDERS[provider]
      raise Auth::VerificationError, "Unsupported provider: #{provider}" unless verifier

      identity = verifier.verify(id_token)
      user = find_or_create_user(provider, identity)
      tokens = generate_tokens(user)

      { user: user, **tokens }
    end

    class << self
      private

      def find_or_create_user(provider, identity)
        # First: find by provider + uid (returning user)
        user = User.find_by(provider: provider, provider_uid: identity[:provider_uid])
        return user if user

        # Second: find by email (first social login, account linking)
        user = User.find_by(email: identity[:email])
        if user
          user.update!(provider: provider, provider_uid: identity[:provider_uid])
          return user
        end

        # Last resort: create new user
        User.create!(
          email: identity[:email],
          name: identity[:name],
          provider: provider,
          provider_uid: identity[:provider_uid],
          avatar_url: identity[:avatar_url],
          role: :client
        )
      end

      def generate_tokens(user)
        access_token = JwtService.encode(user_id: user.id)
        refresh_token = user.refresh_tokens.create!(
          token: SecureRandom.hex(32),
          expires_at: JwtService::REFRESH_TOKEN_EXPIRY.from_now
        )

        { access_token: access_token, refresh_token: refresh_token.token }
      end
    end
  end
end
