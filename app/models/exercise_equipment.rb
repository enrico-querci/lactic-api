class ExerciseEquipment < ApplicationRecord
  # Rails treats "equipment" as uncountable only as a standalone word, so it
  # would otherwise pluralize this class to `exercise_equipments`. The table
  # keeps the singular form the plan specifies.
  self.table_name = "exercise_equipment"

  belongs_to :exercise
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :exercise_id }
end
