class CoachAccess
  def self.allowed?(email)
    allowed_emails.include?(email.to_s.strip.downcase)
  end

  def self.allowed_emails
    ENV.fetch("COACH_EMAILS", "")
      .split(",")
      .map { |email| email.strip.downcase }
      .reject(&:blank?)
  end
end
