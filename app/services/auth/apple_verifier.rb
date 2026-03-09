module Auth
  class AppleVerifier
    def self.verify(id_token)
      token = AppleID::IdToken.new(id_token)
      token.verify!(
        client_id: Rails.application.credentials.dig(:apple, :client_id)
      )

      {
        email: token.email,
        name: token.email.split("@").first,
        provider_uid: token.sub
      }
    rescue => e
      raise Auth::VerificationError, "Apple verification failed: #{e.message}"
    end
  end
end
