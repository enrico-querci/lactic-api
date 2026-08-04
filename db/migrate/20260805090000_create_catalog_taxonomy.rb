# Normalized muscle and equipment taxonomies for the rebuilt exercise catalog.
#
# Replaces the single free-text `exercises.muscle_group` column, which cannot
# express primary/secondary roles or more than one muscle per exercise.
#
# `muscles.region` holds the coarse grouping the provider calls `bodyPart`
# (for example Abs -> Waist). Storing it on the muscle rather than on the
# exercise was verified against a 140-record sample spread across the whole
# provider catalog: every target mapped to exactly one bodyPart, covering 17
# of the 19 published targets. If a future provider ever violates that, this
# column has to move to `exercises`.
class CreateCatalogTaxonomy < ActiveRecord::Migration[8.1]
  def change
    create_table :muscles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :region

      t.timestamps
    end

    add_index :muscles, :key, unique: true
    add_index :muscles, :region

    create_table :equipment do |t|
      t.string :key, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :equipment, :key, unique: true
  end
end
