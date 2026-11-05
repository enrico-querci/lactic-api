module ClientProfiles
  # Ties a client's new account to the coach's profile of them once they
  # accept an invitation: the prepared profile for that email if there is one,
  # otherwise a fresh one from the account, so every client has a profile.
  #
  # It runs inside the acceptance, which it must never fail: the profile is
  # the coach's own record and not part of what the invitation protects, so
  # any problem here is reported and the client still joins.
  class LinkUser
    def self.call(coach:, user:, invitation_email:)
      ActiveRecord::Base.transaction(requires_new: true) do
        profile = coach.client_profiles.find_by(user_id: user.id) ||
                  coach.client_profiles.find_by(user_id: nil, email: invitation_email.to_s.strip.downcase)

        if profile
          profile.update!(user: user)
        else
          coach.client_profiles.create!(user: user, name: user.name.to_s.truncate(100), email: free_email(coach, user))
        end
      end
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Client profile link failed: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, tags: { user_id: user.id.to_s })
      nil
    end

    # The coach may already hold a profile with this address that the
    # invitation did not match (a differently dotted Gmail address, say);
    # emails are unique per coach, so the new profile goes without one.
    def self.free_email(coach, user)
      email = user.email.to_s.strip.downcase
      coach.client_profiles.exists?(email: email) ? nil : email
    end
    private_class_method :free_email
  end
end
