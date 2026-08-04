# Join tables linking exercises to the normalized taxonomies.
#
# Muscles carry a role. For v1 planning metrics the plan counts configured sets
# against the single primary muscle, so `exercise_muscles` is constrained to at
# most one primary row per exercise; secondary muscles are unbounded and exist
# for display and search.
#
# Equipment is a join rather than a belongs_to even though the provider sends a
# single string per exercise, because that string is sometimes a compound:
# the published equipment list includes "Dumbbell, Exercise Ball" and
# "Dumbbell, Exercise Ball, Tennis Ball". Stage 2 splits those on commas into
# several rows. Coach-owned custom exercises may likewise need more than one.
class CreateExerciseMusclesAndEquipment < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_muscles do |t|
      t.references :exercise, null: false, foreign_key: true
      t.references :muscle, null: false, foreign_key: true
      t.string :role, null: false, default: "primary"

      t.timestamps
    end

    add_index :exercise_muscles, %i[exercise_id muscle_id], unique: true
    add_index :exercise_muscles, %i[exercise_id role]

    # At most one primary muscle per exercise, so volume metrics cannot
    # double-count. Secondary rows are unrestricted.
    add_index :exercise_muscles, :exercise_id,
      unique: true,
      where: "role = 'primary'",
      name: "index_exercise_muscles_on_single_primary"

    add_check_constraint :exercise_muscles,
      "role IN ('primary', 'secondary')",
      name: "exercise_muscles_role"

    create_table :exercise_equipment do |t|
      t.references :exercise, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true

      t.timestamps
    end

    add_index :exercise_equipment, %i[exercise_id equipment_id], unique: true
  end
end
