# "equipment" is uncountable in the Rails inflector, so the class, table, and
# association names are all the same word.
class Equipment < ApplicationRecord
  has_many :exercise_equipment, class_name: "ExerciseEquipment", dependent: :destroy
  has_many :exercises, through: :exercise_equipment

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end
