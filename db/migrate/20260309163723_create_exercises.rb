class CreateExercises < ActiveRecord::Migration[8.1]
  def change
    create_table :exercises do |t|
      t.string :name, null: false
      t.string :muscle_group, null: false
      t.string :video_url
      t.string :thumbnail_url
      t.boolean :is_custom, null: false, default: false
      t.references :coach, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :exercises, :muscle_group
    add_index :exercises, :name
  end
end
