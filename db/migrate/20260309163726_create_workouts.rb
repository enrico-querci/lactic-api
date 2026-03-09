class CreateWorkouts < ActiveRecord::Migration[8.1]
  def change
    create_table :workouts do |t|
      t.references :week, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :day, null: false

      t.timestamps
    end

    add_index :workouts, %i[week_id day]
  end
end
