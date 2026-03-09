class SetLog < ApplicationRecord
  include Positionable

  belongs_to :exercise_log

  validates :position, uniqueness: { scope: :exercise_log_id }
  validates :weight_kg, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reps, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
