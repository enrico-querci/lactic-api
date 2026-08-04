# Adds provider-catalog fields to `exercises`.
#
# This migration is deliberately ADDITIVE. `name`, `muscle_group`,
# `thumbnail_url`, and `video_url` are left in place and still NOT NULL:
#
#   * Stage 1 must not delete production data.
#   * `ExerciseBlueprint`, both exercises controllers, and `db/seeds.rb` still
#     read those columns. Stage 5 owns the API contract change and Stage 7
#     owns the reset that finally drops them.
#
# CONSEQUENCE FOR STAGE 2: because `name` and `muscle_group` remain NOT NULL,
# the importer MUST write both on every provider row — the English name and
# the primary muscle — in addition to creating the translation and muscle
# association. They act as a denormalized compatibility shim until Stage 5.
#
# `source_updated_at` from the plan is intentionally omitted. The provider
# exposes no per-record timestamp of any kind (verified across 140 records),
# so the column would never be populated. `content_checksum` is the only
# change-detection mechanism, which is why the plan specifies it.
class AddCatalogFieldsToExercises < ActiveRecord::Migration[8.1]
  def change
    change_table :exercises, bulk: true do |t|
      # Provider identity. Null for coach-owned custom exercises.
      # `source_uid` is a STRING: provider ids are zero-padded and
      # non-sequential ("0001", "0006"), so casting to an integer would
      # collide "0001" with "1".
      t.string :source
      t.string :source_uid

      # Taxonomy carried straight from the provider.
      t.string :category
      t.string :difficulty
      t.string :mechanic
      t.string :force

      # How this exercise is prescribed. v1 ships repetitions only; the
      # provider catalog does contain cardio, balance, and flexibility work
      # (roughly 14% of a 140-record sample), which reps cannot express.
      t.string :prescription_type, null: false, default: "repetitions"

      # `active`   - the provider still lists this record.
      # `assignable` - it passes Lactic's own quality and product gates.
      t.boolean :active, null: false, default: true
      t.boolean :assignable, null: false, default: true

      t.string :content_checksum
      t.datetime :last_synced_at
    end

    # Provider identity is unique per source. Partial index because custom
    # exercises leave both columns null, matching the house style already used
    # for pending client invitations.
    add_index :exercises, %i[source source_uid],
      unique: true,
      where: "source IS NOT NULL AND source_uid IS NOT NULL",
      name: "index_exercises_on_provider_identity"

    add_index :exercises, %i[active assignable]

    # A custom exercise belongs to a coach; a catalog exercise never does.
    #
    # Added NOT VALID (validate: false). The old model only enforced "custom
    # requires a coach", never "catalog must not have one", so production may
    # hold a catalog row with a coach_id. Validating here would abort the
    # migration, and the production entrypoint runs db:prepare on every deploy.
    # NOT VALID still enforces the rule on every insert and update; it only
    # skips the scan of pre-existing rows. Stage 7 resets the catalog, after
    # which a follow-up migration can run validate_check_constraint.
    add_check_constraint :exercises,
      "(is_custom = TRUE AND coach_id IS NOT NULL) OR (is_custom = FALSE AND coach_id IS NULL)",
      name: "exercises_custom_ownership",
      validate: false

    # Provider identity belongs only to catalog exercises, and is all-or-nothing.
    # Safe to validate: every existing row predates provider sync, so both
    # columns are null and satisfy the first branch.
    add_check_constraint :exercises,
      "(source IS NULL AND source_uid IS NULL) OR (source IS NOT NULL AND source_uid IS NOT NULL AND is_custom = FALSE)",
      name: "exercises_provider_identity"
  end
end
