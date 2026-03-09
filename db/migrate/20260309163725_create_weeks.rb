class CreateWeeks < ActiveRecord::Migration[8.1]
  def change
    create_table :weeks do |t|
      t.references :program, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :weeks, %i[program_id position], unique: true
  end
end
