class CreateWorkoutSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_sessions do |t|
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :workout, null: false, foreign_key: true
      t.references :program_assignment, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.text :notes

      t.timestamps
    end
  end
end
