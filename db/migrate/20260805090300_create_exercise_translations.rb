# Localized exercise content, one row per exercise per locale.
#
# English comes from the provider; Italian is generated during synchronization
# in Stage 3 and stored here. Translation never happens during a user request.
#
# `source_checksum` records the checksum of the English content a translation
# was derived from, so a sync can tell whether a stored translation is stale
# without re-translating unchanged rows.
#
# `translation_source` distinguishes provider-supplied text from machine
# output and from human review. A human-reviewed row must never be overwritten
# automatically; the model enforces that.
class CreateExerciseTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :exercise_translations do |t|
      t.references :exercise, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :name, null: false
      t.text :description
      # Ordered list of instruction steps. jsonb rather than a separate table:
      # steps are only ever read and written as a whole ordered unit.
      t.jsonb :instructions, null: false, default: []
      t.string :translation_source, null: false, default: "provider"
      t.string :source_checksum
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :exercise_translations, %i[exercise_id locale], unique: true
    add_index :exercise_translations, :name

    add_check_constraint :exercise_translations,
      "translation_source IN ('provider', 'machine', 'human')",
      name: "exercise_translations_source"
  end
end
