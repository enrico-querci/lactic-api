module ClientInvitations
  class Accept
    class AcceptanceError < StandardError; end

    GMAIL_DOMAINS = %w[gmail.com googlemail.com].freeze

    def self.call(invitation:, user:)
      invitation.with_lock do
        raise AcceptanceError, "This invitation is no longer valid" unless invitation.pending?
        raise AcceptanceError, "Sign in with #{invitation.email} to accept this invitation" unless emails_match?(invitation, user)
        raise AcceptanceError, "A coach account cannot accept a client invitation" unless user.client?

        if user.coach_id.present? && user.coach_id != invitation.coach_id
          raise AcceptanceError, "This account already belongs to another coach"
        end

        user.update!(coach: invitation.coach)
        invitation.update!(accepted_at: Time.current)
      end

      user
    end

    def self.emails_match?(invitation, user)
      normalize_for_comparison(invitation.email) == normalize_for_comparison(user.email)
    end
    private_class_method :emails_match?

    # Gmail ignores dots in the local part and anything after a "+" when
    # routing mail, and always reports one canonical form as the verified
    # OAuth email — so a coach typing a differently-dotted or "+"-tagged
    # variant of the same Gmail address must still match. Every other
    # domain treats dots and "+" as significant local-part characters, so
    # only gmail.com/googlemail.com addresses get folded this way.
    def self.normalize_for_comparison(email)
      normalized = email.to_s.strip.downcase
      return normalized unless normalized.include?("@")

      local, domain = normalized.split("@", 2)
      return normalized unless GMAIL_DOMAINS.include?(domain)

      "#{local.split("+", 2).first.delete(".")}@#{domain}"
    end
    private_class_method :normalize_for_comparison
  end
end
