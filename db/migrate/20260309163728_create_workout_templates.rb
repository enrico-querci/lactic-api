class CreateWorkoutTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_templates do |t|
      t.references :coach, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.references :source_workout, null: false, foreign_key: { to_table: :workouts }

      t.timestamps
    end
  end
end
