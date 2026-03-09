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

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true
  validate :coach_cannot_have_coach

  scope :coaches, -> { where(role: :coach) }
  scope :clients, -> { where(role: :client) }

  private

  def coach_cannot_have_coach
    if coach? && coach_id.present?
      errors.add(:coach_id, "a coach cannot belong to another coach")
    end
  end
end
