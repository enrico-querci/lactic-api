class User < ApplicationRecord
  enum :role, { coach: "coach", client: "client" }

  belongs_to :coach, class_name: "User", optional: true

  has_many :clients, class_name: "User", foreign_key: :coach_id, dependent: :nullify, inverse_of: :coach
  has_many :programs, foreign_key: :coach_id, dependent: :destroy, inverse_of: :coach
  has_many :exercises, foreign_key: :coach_id, dependent: :destroy, inverse_of: :coach
  has_many :workout_templates, foreign_key: :coach_id, dependent: :destroy, inverse_of: :coach
  has_many :program_assignments, foreign_key: :client_id, dependent: :destroy, inverse_of: :client
  has_many :workout_sessions, foreign_key: :client_id, dependent: :destroy, inverse_of: :client
  has_many :refresh_tokens, dependent: :delete_all
  has_many :client_invitations, foreign_key: :coach_id, dependent: :destroy, inverse_of: :coach
  has_one :coach_subscription, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true
  # Nil means "no explicit preference", which lets a request fall through to
  # Accept-Language and then to English.
  validates :locale, inclusion: { in: ExerciseTranslation::LOCALES }, allow_nil: true
  validate :coach_cannot_have_coach

  scope :coaches, -> { where(role: :coach) }
  scope :clients, -> { where(role: :client) }

  # nil means unlimited. COACH_EMAILS is a comp list, not just a signup
  # gate: it grants unlimited access regardless of billing state, so it
  # keeps working even if RevenueCat is misconfigured or unreachable.
  def client_limit
    return nil if CoachAccess.allowed?(email)

    coach_subscription&.client_limit || Billing::Plans::FREE_CLIENT_LIMIT
  end

  # Pending invitations count against the limit too, otherwise a Free
  # coach could send unlimited invitations and let them sit unaccepted.
  def client_slots_used
    clients.count + client_invitations.pending.where("expires_at > ?", Time.current).count
  end

  def can_invite_client?
    client_limit.nil? || client_slots_used < client_limit
  end

  private

  def coach_cannot_have_coach
    if coach? && coach_id.present?
      errors.add(:coach_id, "a coach cannot belong to another coach")
    end
  end
end
