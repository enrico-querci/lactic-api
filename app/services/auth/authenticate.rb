module Auth
  class Authenticate
    PROVIDERS = {
      "apple" => Auth::AppleVerifier,
      "google" => Auth::GoogleVerifier
    }.freeze

    def self.call(provider:, id_token:, invitation_token: nil)
      verifier = PROVIDERS[provider]
      raise Auth::VerificationError, "Unsupported provider: #{provider}" unless verifier

      identity = verifier.verify(id_token)
      invitation = find_invitation(invitation_token)
      user = User.transaction do
        authenticated_user = find_or_create_user(provider, identity, invitation)
        accept_invitation(invitation, authenticated_user) if invitation
        authenticated_user
      end
      tokens = generate_tokens(user)

      { user: user, **tokens }
    rescue ClientInvitations::Accept::AcceptanceError => e
      raise Auth::VerificationError, e.message
    end

    class << self
      private

      def find_or_create_user(provider, identity, invitation)
        # First: find by provider + uid (returning user)
        user = User.find_by(provider: provider, provider_uid: identity[:provider_uid])
        return user if user

        # Second: find by email (first social login, account linking)
        email = identity[:email].to_s.strip.downcase
        user = User.where("LOWER(email) = ?", email).first
        if user
          user.update!(provider: provider, provider_uid: identity[:provider_uid])
          return user
        end

        role = role_for_new_user(email, invitation)

        User.create!(
          email: email,
          name: identity[:name],
          provider: provider,
          provider_uid: identity[:provider_uid],
          avatar_url: identity[:avatar_url],
          role: role
        )
      end

      def find_invitation(token)
        return if token.blank?

        invitation = ClientInvitation.find_by_token(token)
        raise Auth::VerificationError, "Invalid invitation link" unless invitation
        raise Auth::VerificationError, "This invitation is no longer valid" unless invitation.pending?

        invitation
      end

      def role_for_new_user(email, invitation)
        return :client if invitation
        return :coach if CoachAccess.allowed?(email)

        raise Auth::VerificationError, "An invitation is required to create a client account"
      end

      def accept_invitation(invitation, user)
        ClientInvitations::Accept.call(invitation: invitation, user: user)
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
