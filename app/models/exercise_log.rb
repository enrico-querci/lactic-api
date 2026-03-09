class ExerciseLog < ApplicationRecord
  belongs_to :workout_session
  belongs_to :workout_exercise

  has_many :set_logs, dependent: :destroy
end
