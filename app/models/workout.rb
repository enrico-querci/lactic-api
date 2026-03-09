class Workout < ApplicationRecord
  belongs_to :week

  has_many :workout_exercises, dependent: :destroy
  has_many :exercises, through: :workout_exercises
  has_many :workout_sessions, dependent: :destroy
  has_many :workout_templates, foreign_key: :source_workout_id, dependent: :nullify, inverse_of: :source_workout

  validates :name, presence: true
  validates :day, presence: true, numericality: { only_integer: true, in: 1..7 }

  # Returns a hash of muscle_group => total sets count
  # e.g. { "Chest" => 12, "Triceps" => 9 }
  def volume_sets
    workout_exercises
      .unscope(:order)
      .joins(:exercise)
      .group("exercises.muscle_group")
      .sum(:sets)
  end
end
