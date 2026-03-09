class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :role, null: false, default: "client"
      t.string :avatar_url
      t.references :coach, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :role
  end
end
