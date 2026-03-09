module Auth
  class GoogleVerifier
    def self.verify(id_token)
      validator = GoogleIDToken::Validator.new
      payload = validator.check(
        id_token,
        Rails.application.credentials.dig(:google, :client_id)
      )

      {
        email: payload["email"],
        name: payload["name"] || payload["email"].split("@").first,
        provider_uid: payload["sub"],
        avatar_url: payload["picture"]
      }
    rescue GoogleIDToken::ValidationError => e
      raise Auth::VerificationError, "Google verification failed: #{e.message}"
    end
  end
end
