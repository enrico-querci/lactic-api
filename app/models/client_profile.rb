class ClientProfile < ApplicationRecord
  LEVELS = %w[beginner intermediate advanced].freeze
  GOALS = %w[strength muscle_gain fat_loss health other].freeze

  belongs_to :coach, class_name: "User", inverse_of: :client_profiles
  # Set once the person accepts an invitation; nil while the profile is only
  # prepared or invited.
  belongs_to :user, optional: true, inverse_of: :client_profile

  before_validation :normalize

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :email, uniqueness: { scope: :coach_id, case_sensitive: false }, allow_nil: true
  validates :phone, length: { maximum: 40 }, allow_nil: true
  validates :level, inclusion: { in: LEVELS }, allow_nil: true
  validates :goal, inclusion: { in: GOALS }, allow_nil: true
  validates :limitations, :notes, length: { maximum: 2000 }, allow_nil: true
  validate :coach_must_be_coach

  def linked?
    user_id.present?
  end

  private

  # Blank means "not given", so a cleared field is stored as null and the
  # email's uniqueness check never compares empty strings.
  def normalize
    self.name = name.to_s.strip
    self.email = email.to_s.strip.downcase.presence
    %i[phone level goal limitations notes].each do |attribute|
      self[attribute] = self[attribute].to_s.strip.presence
    end
  end

  def coach_must_be_coach
    errors.add(:coach, "must have the coach role") if coach && !coach.coach?
  end
end
