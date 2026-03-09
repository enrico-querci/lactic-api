class WorkoutExercise < ApplicationRecord
  belongs_to :workout
  belongs_to :exercise

  has_many :exercise_logs, dependent: :destroy

  validates :position, presence: true, format: { with: /\A[A-Z]\z/, message: "must be a single uppercase letter (A-Z)" }
  validates :position, uniqueness: { scope: :workout_id }
  validates :sets, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :reps, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :rest_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rir, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  default_scope { order(position: :asc) }
end
