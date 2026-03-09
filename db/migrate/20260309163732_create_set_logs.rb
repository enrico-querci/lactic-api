class CreateSetLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :set_logs do |t|
      t.references :exercise_log, null: false, foreign_key: true
      t.integer :position, null: false
      t.decimal :weight_kg, precision: 6, scale: 2, null: false
      t.integer :reps, null: false

      t.timestamps
    end

    add_index :set_logs, %i[exercise_log_id position], unique: true
  end
end
