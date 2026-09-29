module Auth
  # Verifies a Sign in with Apple identity token.
  #
  # A native app's token carries its own bundle ID as `aud`, so every iOS
  # app is a separate audience: the client app and Lactic Studio are two.
  # The list must never be empty — AppleID::IdToken#verify! skips the
  # audience check entirely when it is handed a blank one, which would
  # accept a token Apple issued to anybody's app.
  class AppleVerifier
    DEFAULT_CLIENT_IDS = %w[com.enricoquerci.lactic com.enricoquerci.lacticstudio].freeze

    # APPLE_CLIENT_IDS (comma-separated) replaces the defaults, for example
    # to add a web Services ID once the portal offers Sign in with Apple.
    def self.client_ids
      configured = ENV["APPLE_CLIENT_IDS"].to_s.split(",").map(&:strip).reject(&:empty?)
      configured.presence || DEFAULT_CLIENT_IDS
    end

    def self.verify(id_token)
      token = AppleID::IdToken.decode(id_token.to_s)
      audience = token.aud
      raise Auth::VerificationError, "Apple verification failed: unexpected audience" unless client_ids.include?(audience)

      token.verify!(client: audience)
      raise Auth::VerificationError, "Apple did not share an email address" if token.email.blank?
      # Existing accounts are linked by email, so an unverified one could
      # claim somebody else's. Apple verifies personal accounts; the claim
      # can be false for some managed (work or school) ones.
      raise Auth::VerificationError, "Apple could not verify this email address" unless token.email_verified?

      {
        email: token.email,
        # Apple's token never carries a name. The app forwards the one
        # Apple gives it on first authorization, and Auth::Authenticate
        # prefers that over this fallback.
        name: token.email.split("@").first,
        provider_uid: token.sub,
        client_id: audience
      }
    rescue Auth::VerificationError
      raise
    rescue => e
      raise Auth::VerificationError, "Apple verification failed: #{e.message}"
    end
  end
end
