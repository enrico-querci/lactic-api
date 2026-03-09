class CreateProgramAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :program_assignments do |t|
      t.references :program, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :coach, null: false, foreign_key: { to_table: :users }
      t.date :start_date, null: false
      t.text :notes
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :program_assignments, :status
  end
end
