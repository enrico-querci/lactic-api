class ProgramAssignment < ApplicationRecord
  enum :status, { active: "active", completed: "completed", paused: "paused" }

  belongs_to :program
  belongs_to :client, class_name: "User"
  belongs_to :coach, class_name: "User"

  has_many :workout_sessions, dependent: :destroy

  validates :start_date, presence: true
  validates :status, presence: true
  validate :client_must_be_client_role
  validate :coach_must_be_coach_role

  private

  def client_must_be_client_role
    if client && !client.client?
      errors.add(:client, "must have the client role")
    end
  end

  def coach_must_be_coach_role
    if coach && !coach.coach?
      errors.add(:coach, "must have the coach role")
    end
  end
end
