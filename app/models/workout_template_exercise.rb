# One exercise of a WorkoutTemplate, with the same prescription a
# WorkoutExercise carries. It is a copy taken when the template is saved, so
# it never changes when the workout it came from does.
class WorkoutTemplateExercise < ApplicationRecord
  # The columns copied to and from WorkoutExercise.
  PRESCRIPTION_ATTRIBUTES = %w[exercise_id position sets reps rest_seconds rir weight notes].freeze

  belongs_to :workout_template
  belongs_to :exercise

  validates :position, presence: true, format: { with: /\A[A-Z]\z/, message: "must be a single uppercase letter (A-Z)" }
  validates :position, uniqueness: { scope: :workout_template_id }
  validates :sets, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :reps, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :rest_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rir, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  default_scope { order(position: :asc) }
end
