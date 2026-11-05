class WorkoutTemplate < ApplicationRecord
  belongs_to :coach, class_name: "User"
  # Provenance only: the template owns a copy of the exercises, so the workout
  # it was saved from can change or be deleted without touching it.
  belongs_to :source_workout, class_name: "Workout", optional: true

  has_many :workout_template_exercises, dependent: :destroy

  validates :name, presence: true

  # The first unused position letter, which is how a new exercise is placed
  # when the client does not choose one. Nil once all 26 are taken.
  def next_position
    (WorkoutTemplateExercise::POSITIONS - workout_template_exercises.pluck(:position)).first
  end
end
