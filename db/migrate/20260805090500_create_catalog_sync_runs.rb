# Audit record for one provider synchronization run.
#
# `error_summary` is a redacted, human-readable string. Never write a provider
# API key, a full upstream URL, or raw upstream headers into this table.
class CreateCatalogSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_sync_runs do |t|
      t.string :source, null: false
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.integer :fetched_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :deactivated_count, null: false, default: 0
      t.integer :rejected_count, null: false, default: 0

      t.text :error_summary

      t.timestamps
    end

    add_index :catalog_sync_runs, %i[source started_at]

    add_check_constraint :catalog_sync_runs,
      "status IN ('running', 'succeeded', 'failed')",
      name: "catalog_sync_runs_status"
  end
end
