class CreateExerciseLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_logs do |t|
      t.references :workout_session, null: false, foreign_key: true
      t.references :workout_exercise, null: false, foreign_key: true
      t.text :notes
      t.string :photo_url

      t.timestamps
    end
  end
end
