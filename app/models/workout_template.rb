class WorkoutTemplate < ApplicationRecord
  belongs_to :coach, class_name: "User"
  belongs_to :source_workout, class_name: "Workout"

  validates :name, presence: true
end
