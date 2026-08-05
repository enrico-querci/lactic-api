require "test_helper"

module Catalog
  class SyncTest < ActiveSupport::TestCase
    # A provider that replays canned records. Sync must not know or care
    # whether it is talking to WorkoutX.
    class FakeProvider
      attr_reader :source

      def initialize(records, source: "workoutx", total: nil, raise_on_record: nil)
        @records = records
        @source = source
        @total = total.nil? ? records.size : total
        @raise_on_record = raise_on_record
      end

      def total_count = @total

      def each_record(page_size: nil)
        return enum_for(:each_record) unless block_given?

        @records.each_with_index do |record, index|
          raise @raise_on_record if @raise_on_record && index == 1

          yield record
        end
      end
    end

    def raw_records
      @raw_records ||= JSON.parse(
        file_fixture("workoutx/exercises_list_response.json").read
      ).fetch("data")
    end

    def sync(records = raw_records, **options)
      Sync.call(provider: FakeProvider.new(records, **options))
    end

    setup do
      TaxonomySeeder.call
      # The fixtures include two provider-sourced exercises whose source_uids
      # collide with the captured response, which would make every count in
      # this file ambiguous. Clear provider rows only — the catalog and custom
      # fixtures stay, because several tests assert the sync leaves them alone.
      Exercise.where.not(source: nil).destroy_all
    end

    # --- Initial import -----------------------------------------------------

    test "imports the provider catalog" do
      run = sync

      assert_equal "succeeded", run.status
      assert_equal 3, run.created_count
      assert_equal 0, run.rejected_count
      assert_equal 3, Exercise.from_source("workoutx").count
      assert_equal %w[0001 0002 0003], Exercise.from_source("workoutx").order(:source_uid).pluck(:source_uid)
    end

    test "builds the full record graph" do
      sync
      exercise = Exercise.find_by(source: "workoutx", source_uid: "0001")

      assert_equal "3/4 Sit-up", exercise.name
      assert_equal "Abs", exercise.muscle_group
      assert_equal "strength", exercise.category
      assert exercise.assignable?
      assert_equal "Abs", exercise.primary_muscle.name
      assert_equal [ "Hip Flexors", "Lower Back" ], exercise.secondary_muscles.map(&:name)
      assert_equal [ "Body Weight" ], exercise.equipment.map(&:name)
      assert_equal "image/gif", exercise.animation.mime_type
      assert_equal "3/4 Sit-up", exercise.translation_for("en").name
      assert_equal 5, exercise.translation_for("en").instructions.size
    end

    test "populates the legacy NOT NULL columns that the current API still reads" do
      sync

      Exercise.from_source("workoutx").find_each do |exercise|
        assert exercise.name.present?
        assert exercise.muscle_group.present?
      end
    end

    test "records a sync run with counts and timing" do
      run = sync

      assert_equal "workoutx", run.source
      assert_equal 3, run.fetched_count
      assert_not_nil run.finished_at
      assert_operator run.duration_seconds, :>=, 0
    end

    # --- Idempotence --------------------------------------------------------

    test "a repeat import creates nothing and changes nothing" do
      sync
      before = Exercise.from_source("workoutx").order(:source_uid).pluck(:id, :updated_at)

      run = sync

      assert_equal 0, run.created_count
      assert_equal 0, run.updated_count
      # updated_at must stay put so it remains a signal that content actually
      # changed, rather than a record of the last time a sync ran.
      assert_equal before, Exercise.from_source("workoutx").order(:source_uid).pluck(:id, :updated_at)
    end

    test "an unchanged record still records that it was seen" do
      sync
      exercise = Exercise.find_by(source_uid: "0001")
      exercise.update_columns(last_synced_at: 3.days.ago)

      sync

      assert_operator exercise.reload.last_synced_at, :>, 1.hour.ago
    end

    test "a repeat import does not churn associations" do
      sync
      before = ExerciseMuscle.order(:id).pluck(:id)

      sync

      assert_equal before, ExerciseMuscle.order(:id).pluck(:id)
    end

    # --- Updates ------------------------------------------------------------

    test "changed content updates in place and keeps the lactic id" do
      sync
      original = Exercise.find_by(source_uid: "0001")

      changed = raw_records.map(&:dup)
      changed[0]["name"] = "Renamed Sit-up"
      run = sync(changed)

      assert_equal 1, run.updated_count
      assert_equal original.id, Exercise.find_by(source_uid: "0001").id
      assert_equal "Renamed Sit-up", original.reload.name
      assert_equal "Renamed Sit-up", original.translation_for("en").name
    end

    test "a changed primary muscle swaps roles without violating the single primary rule" do
      sync
      exercise = Exercise.find_by(source_uid: "0001")

      changed = raw_records.map(&:dup)
      changed[0]["target"] = "Glutes"
      changed[0]["bodyPart"] = "Upper Legs"
      sync(changed)

      assert_equal "Glutes", exercise.reload.primary_muscle.name
      assert_equal 1, exercise.exercise_muscles.where(role: "primary").count
    end

    test "changed equipment is replaced" do
      sync
      exercise = Exercise.find_by(source_uid: "0001")

      changed = raw_records.map(&:dup)
      changed[0]["equipment"] = "Barbell, Exercise Ball"
      sync(changed)

      assert_equal [ "Barbell", "Exercise Ball" ], exercise.reload.equipment.map(&:name).sort
    end

    test "an unknown secondary muscle is created rather than rejected" do
      changed = raw_records.map(&:dup)
      changed[0]["secondaryMuscles"] = [ "Brand New Muscle" ]

      run = sync(changed)

      assert_equal 0, run.rejected_count
      assert Muscle.exists?(key: "brand_new_muscle")
      assert_nil Muscle.find_by(key: "brand_new_muscle").region
    end

    test "live data fills in a region the seed file had to infer" do
      Muscle.find_by(key: "abs").update!(region: nil)
      sync

      assert_equal "Waist", Muscle.find_by(key: "abs").region
    end

    # --- Human-reviewed content --------------------------------------------

    test "a human edited english translation is not overwritten" do
      sync
      translation = Exercise.find_by(source_uid: "0001").translation_for("en")
      translation.update!(name: "Coach's wording", translation_source: "human", reviewed_at: Time.current)

      changed = raw_records.map(&:dup)
      changed[0]["name"] = "Provider wording"
      sync(changed)

      assert_equal "Coach's wording", translation.reload.name
    end

    # --- Custom exercises ---------------------------------------------------

    test "custom exercises are never touched" do
      custom = exercises(:custom_exercise)
      before = custom.attributes

      sync

      assert_equal before, custom.reload.attributes
    end

    test "custom exercises are never deactivated" do
      sync

      assert exercises(:custom_exercise).reload.active?
    end

    # --- Rejection ----------------------------------------------------------

    test "a malformed record is quarantined and the rest still import" do
      records = raw_records.map(&:dup)
      records[1] = records[1].merge("gifUrl" => nil, "target" => nil)

      run = sync(records)

      assert_equal "succeeded", run.status
      assert_equal 1, run.rejected_count
      assert_equal 2, run.created_count
      assert_includes run.error_summary, "missing gifUrl"
    end

    test "the rejection summary aggregates reasons rather than dumping records" do
      records = raw_records.map { |r| r.merge("gifUrl" => nil) }

      run = sync(records)

      assert_equal 3, run.rejected_count
      assert_includes run.error_summary, "missing gifUrl (3)"
      assert_not_includes run.error_summary, "Sit-up"
    end

    # --- Deactivation -------------------------------------------------------

    test "a record the provider stops publishing is deactivated, never deleted" do
      sync
      retired = Exercise.find_by(source_uid: "0002")

      sync(raw_records.reject { |r| r["id"] == "0002" }, total: 2)

      assert Exercise.exists?(retired.id), "must never hard delete"
      assert_not retired.reload.active?
    end

    test "a deactivated record still resolves for history but leaves the picker" do
      sync
      sync(raw_records.reject { |r| r["id"] == "0002" }, total: 2)

      coach_id = users(:coach_john).id
      retired = Exercise.find_by(source_uid: "0002")

      assert_includes Exercise.for_coach(coach_id), retired
      assert_not_includes Exercise.selectable(coach_id), retired
    end

    test "a short catalog does not deactivate everything" do
      sync

      # The provider claims 1327 records but only returns one: an outage, not
      # a catalog that shrank. Deactivating here would retire the whole catalog.
      assert_raises(Sync::IncompleteCatalog) { sync([ raw_records.first ], total: 1327) }

      assert Exercise.from_source("workoutx").where(active: true).count >= 3
    end

    test "an incomplete run is recorded as failed" do
      sync
      assert_raises(Sync::IncompleteCatalog) { sync([ raw_records.first ], total: 1327) }

      assert_equal "failed", CatalogSyncRun.recent.first.status
    end

    # --- Failure handling ---------------------------------------------------

    test "a provider failure marks the run failed and re-raises" do
      assert_raises(Providers::Errors::Transient) do
        sync(raw_records, raise_on_record: Providers::Errors::Transient.new("provider error (HTTP 503)"))
      end

      run = CatalogSyncRun.recent.first
      assert_equal "failed", run.status
      assert_includes run.error_summary, "provider error (HTTP 503)"
    end

    test "records imported before a failure are kept" do
      assert_raises(Providers::Errors::Transient) do
        sync(raw_records, raise_on_record: Providers::Errors::Transient.new("boom"))
      end

      assert Exercise.exists?(source: "workoutx", source_uid: "0001")
    end

    test "the error summary never contains a credential" do
      assert_raises(Providers::Errors::Authentication) do
        sync(raw_records, raise_on_record: Providers::Errors::Authentication.new("provider rejected the credentials (HTTP 401)"))
      end

      summary = CatalogSyncRun.recent.first.error_summary
      assert_no_match(/wx_[A-Za-z0-9]/, summary)
      assert_includes summary, "HTTP 401"
    end
  end
end
