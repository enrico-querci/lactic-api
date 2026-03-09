class CreatePrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :programs do |t|
      t.string :name, null: false
      t.text :description
      t.references :coach, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
