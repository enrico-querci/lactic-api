require "test_helper"

class CatalogSyncRunTest < ActiveSupport::TestCase
  test "valid run" do
    assert catalog_sync_runs(:successful_run).valid?
  end

  test "requires source, status and started_at" do
    run = CatalogSyncRun.new(status: nil)
    assert_not run.valid?
    assert_includes run.errors[:source], "can't be blank"
    assert_includes run.errors[:status], "can't be blank"
    assert_includes run.errors[:started_at], "can't be blank"
  end

  test "rejects an unknown status" do
    run = CatalogSyncRun.new(source: "workoutx", status: "confused", started_at: Time.current)
    assert_not run.valid?
    assert_includes run.errors[:status], "is not included in the list"
  end

  test "database rejects an unknown status even without validations" do
    run = CatalogSyncRun.new(source: "workoutx", status: "confused", started_at: Time.current)
    assert_raises(ActiveRecord::StatementInvalid) { run.save(validate: false) }
  end

  test "counters default to zero" do
    run = CatalogSyncRun.create!(source: "workoutx", started_at: Time.current)
    assert_equal 0, run.fetched_count
    assert_equal 0, run.rejected_count
    assert run.running?
  end

  test "finish! records status, completion time and a redacted summary" do
    run = catalog_sync_runs(:running_run)
    run.finish!(status: "failed", error_summary: "Upstream returned 500")

    assert_equal "failed", run.status
    assert_not_nil run.finished_at
    assert_equal "Upstream returned 500", run.error_summary
    assert_not run.running?
  end

  test "duration is nil until the run finishes" do
    assert_nil catalog_sync_runs(:running_run).duration_seconds
    assert_in_delta 3600, catalog_sync_runs(:successful_run).duration_seconds, 5
  end

  test "recent orders newest first" do
    assert_equal catalog_sync_runs(:running_run), CatalogSyncRun.recent.first
  end

  test "for_source scope" do
    assert_equal 3, CatalogSyncRun.for_source("workoutx").count
    assert_equal 0, CatalogSyncRun.for_source("nobody").count
  end
end
