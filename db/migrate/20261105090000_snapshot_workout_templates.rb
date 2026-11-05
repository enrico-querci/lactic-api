# A workout template used to be a pointer to a live workout: editing that
# workout silently rewrote the template, and deleting it hit the NOT NULL
# source_workout_id (Workout's `dependent: :nullify` is an UPDATE, so Postgres
# rejected it). A template now owns its own copy of the exercises, taken when
# it is saved, and keeps source_workout_id only as optional provenance.
#
# Existing templates have no copy to fall back on and the owner chose not to
# backfill them, so they are removed. Nothing else is touched: programmes,
# assignments, sessions and logs are not related to templates.
class SnapshotWorkoutTemplates < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM workout_templates"

    create_table :workout_template_exercises do |t|
      t.references :workout_template, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.string :position, null: false
      t.integer :sets, null: false
      t.integer :reps, null: false
      t.integer :rest_seconds
      t.integer :rir
      t.decimal :weight, precision: 6, scale: 2
      t.text :notes

      t.timestamps
    end
    add_index :workout_template_exercises, %i[workout_template_id position],
              unique: true, name: "index_workout_template_exercises_on_template_and_position"

    change_column_null :workout_templates, :source_workout_id, true
    remove_foreign_key :workout_templates, column: :source_workout_id
    add_foreign_key :workout_templates, :workouts, column: :source_workout_id, on_delete: :nullify
  end

  def down
    execute "DELETE FROM workout_templates WHERE source_workout_id IS NULL"

    remove_foreign_key :workout_templates, column: :source_workout_id
    add_foreign_key :workout_templates, :workouts, column: :source_workout_id
    change_column_null :workout_templates, :source_workout_id, false

    drop_table :workout_template_exercises
  end
end
