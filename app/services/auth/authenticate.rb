module Auth
  class Authenticate
    PROVIDERS = {
      "apple" => Auth::AppleVerifier,
      "google" => Auth::GoogleVerifier
    }.freeze

    # Which role each native app serves. The web sends no `app` and keeps
    # today's behaviour: one portal routes either role by its guards.
    #
    # This only ever refuses; it never decides a role. A client-supplied
    # value choosing a role would let anyone make themselves a coach (or
    # client), which AGENTS.md §2.3 forbids. Refusing a sign-in the app
    # could not serve anyway grants nothing.
    APP_ROLES = { "lactic" => "client", "studio" => "coach" }.freeze

    # `name` and `authorization_code` are Sign in with Apple only, and both
    # come from the app rather than the verified token. Apple hands the app
    # the user's name on first authorization and never again, and its token
    # never carries one — so a forwarded name is the only real name an
    # Apple account will ever have. It is used when creating a user and
    # ignored otherwise. Google's verified token already names the user.
    def self.call(provider:, id_token:, invitation_token: nil, name: nil, authorization_code: nil, app: nil)
      verifier = PROVIDERS[provider]
      raise Auth::VerificationError, "Unsupported provider: #{provider}" unless verifier
      raise Auth::VerificationError, "Unsupported app: #{app}" if app.present? && !APP_ROLES.key?(app)

      identity = verifier.verify(id_token)
      if provider == "apple" && (forwarded_name = name.to_s.squish.presence)
        identity = identity.merge(name: forwarded_name)
      end
      invitation = find_invitation(invitation_token)
      user = User.transaction do
        authenticated_user = find_or_create_user(provider, identity, invitation, app)
        accept_invitation(invitation, authenticated_user) if invitation
        authenticated_user
      end
      # Outside the transaction: a call to Apple should never hold a lock,
      # and its failure must not undo a successful sign-in.
      if provider == "apple"
        Auth::AppleAuthorization.remember(user: user, code: authorization_code, client_id: identity[:client_id])
      end
      tokens = generate_tokens(user)

      { user: user, **tokens }
    rescue ClientInvitations::Accept::AcceptanceError => e
      raise Auth::VerificationError, e.message
    end

    class << self
      private

      def find_or_create_user(provider, identity, invitation, app)
        # First: find by provider + uid (returning user)
        user = User.find_by(provider: provider, provider_uid: identity[:provider_uid])
        if user
          ensure_app_serves!(app, user.role)
          return user
        end

        # Second: find by email (first social login, account linking)
        email = identity[:email].to_s.strip.downcase
        user = User.where("LOWER(email) = ?", email).first
        if user
          ensure_app_serves!(app, user.role)
          user.update!(provider: provider, provider_uid: identity[:provider_uid])
          return user
        end

        role = role_for_new_user(email, invitation)
        ensure_app_serves!(app, role.to_s, new_user: true)

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

      # Coach signup is open: any new Google/Apple identity becomes a
      # coach unless it came in through a client invitation. The one
      # failure mode this guards against is an invited client signing in
      # from the plain login page instead of their invitation link — that
      # would otherwise silently create them as a coach rather than
      # linking them to the coach who invited them.
      def role_for_new_user(email, invitation)
        return :client if invitation

        if ClientInvitation.pending.where(email: email).where("expires_at > ?", Time.current).exists?
          raise Auth::VerificationError, "Open your invitation link to join your coach"
        end

        :coach
      end

      # Raised before anything is written, so a refused sign-in creates no
      # user and links no identity.
      def ensure_app_serves!(app, role, new_user: false)
        return if app.blank? || APP_ROLES[app] == role

        message =
          if app == "lactic" && new_user
            "There is no Lactic account for this email. Open the invitation link from your coach to join."
          elsif app == "lactic"
            "This is a coach account. Sign in to Lactic Studio instead."
          else
            "This is a client account. Sign in to the Lactic app instead."
          end
        raise Auth::VerificationError, message
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
