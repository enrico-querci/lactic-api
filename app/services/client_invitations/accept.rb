module ClientInvitations
  class Accept
    class AcceptanceError < StandardError; end

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
      invitation.email.casecmp?(user.email)
    end
    private_class_method :emails_match?
  end
end
