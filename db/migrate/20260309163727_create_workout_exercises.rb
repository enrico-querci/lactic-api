class CreateWorkoutExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_exercises do |t|
      t.references :workout, null: false, foreign_key: true
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

    add_index :workout_exercises, %i[workout_id position], unique: true
  end
end
