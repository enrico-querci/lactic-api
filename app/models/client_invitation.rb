require "digest"

class ClientInvitation < ApplicationRecord
  EXPIRATION = 7.days

  belongs_to :coach, class_name: "User", inverse_of: :client_invitations

  attr_reader :raw_token

  before_validation :normalize_email
  before_validation :issue_token, on: :create

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :coach_must_be_coach

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil) }
  scope :recent_first, -> { order(created_at: :desc) }

  def self.find_by_token(token)
    return if token.blank?

    find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def pending?
    accepted_at.nil? && revoked_at.nil? && !expired?
  end

  def expired?
    expires_at <= Time.current
  end

  def status
    return "accepted" if accepted_at.present?
    return "revoked" if revoked_at.present?
    return "expired" if expired?

    "pending"
  end

  def renew!
    issue_token
    self.expires_at = EXPIRATION.from_now
    self.sent_at = nil
    save!
    raw_token
  end

  def mark_sent!
    update!(sent_at: Time.current)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private

  def issue_token
    @raw_token = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(raw_token)
    self.expires_at ||= EXPIRATION.from_now
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def coach_must_be_coach
    errors.add(:coach, "must have the coach role") if coach && !coach.coach?
  end
end
