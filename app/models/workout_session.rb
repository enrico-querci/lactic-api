class WorkoutSession < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :workout
  belongs_to :program_assignment

  has_many :exercise_logs, dependent: :destroy

  validate :client_must_be_client_role

  private

  def client_must_be_client_role
    if client && !client.client?
      errors.add(:client, "must have the client role")
    end
  end
end
