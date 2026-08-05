require "test_helper"

module Catalog
  class ResetPlanTest < ActiveSupport::TestCase
    test "legacy scope covers the hand-seeded catalog only" do
      report = ResetPlan.call(scope: :legacy)

      target = ResetPlan.new(scope: :legacy).target
      assert_includes target, exercises(:bench_press)
      assert_not_includes target, exercises(:provider_situp), "provider rows are not legacy"
      assert_not_includes target, exercises(:custom_exercise), "custom is never legacy"
      assert_equal Exercise.catalog.where(source: nil).count, report.exercises
    end

    test "catalog scope includes provider rows but still spares custom" do
      target = ResetPlan.new(scope: :catalog).target

      assert_includes target, exercises(:provider_situp)
      assert_not_includes target, exercises(:custom_exercise)
    end

    test "everything scope includes custom, which is why it is never the default" do
      target = ResetPlan.new(scope: :everything).target

      assert_includes target, exercises(:custom_exercise)
      assert_equal :legacy, ResetPlan.new.call.scope
    end

    test "rejects an unknown scope rather than silently doing nothing" do
      assert_raises(ArgumentError) { ResetPlan.new(scope: :oops) }
    end

    test "counts the full destroy cascade, not just exercises" do
      # bench_press is referenced by a workout exercise, which has logs, which
      # have set logs. That chain is the point of the report.
      report = ResetPlan.call(scope: :legacy)

      assert_operator report.workout_exercises, :>, 0
      assert_operator report.exercise_logs, :>, 0
      assert_operator report.set_logs, :>, 0
      assert report.destroys_client_data?
    end

    test "counts associated catalog rows for provider exercises" do
      report = ResetPlan.call(scope: :catalog)

      assert_operator report.translations, :>, 0
      assert_operator report.muscle_links, :>, 0
      assert_operator report.media, :>, 0
    end

    test "reports workouts that would be left empty" do
      report = ResetPlan.call(scope: :catalog)

      # Every workout_exercise in the fixtures points at a catalog exercise, so
      # clearing the catalog empties their workouts.
      assert_operator report.emptied_workouts, :>, 0
    end

    test "reports how many custom exercises survive" do
      assert_equal Exercise.custom.count, ResetPlan.call(scope: :legacy).custom_exercises
      assert_equal 0, ResetPlan.call(scope: :everything).custom_exercises
    end

    test "an empty scope is not destructive" do
      Exercise.catalog.where(source: nil).destroy_all

      report = ResetPlan.call(scope: :legacy)

      assert_equal 0, report.exercises
      assert_not report.destructive?
    end

    test "the report names the client-data risk explicitly" do
      assert_includes ResetPlan.call(scope: :legacy).to_s, "client-logged weights and reps"
    end
  end

  class ResetCatalogTest < ActiveSupport::TestCase
    def legacy_count = Exercise.catalog.where(source: nil).count

    test "deletes the scoped exercises when the count matches" do
      expected = legacy_count

      result = ResetCatalog.call(scope: :legacy, expected_exercises: expected)

      assert_equal expected, result.deleted
      assert_equal 0, legacy_count
    end

    test "refuses when the data changed since the plan was reviewed" do
      error = assert_raises(ResetCatalog::CountMismatch) do
        ResetCatalog.call(scope: :legacy, expected_exercises: legacy_count + 1)
      end

      assert_includes error.message, "Re-run the plan"
      assert_operator legacy_count, :>, 0, "nothing may be deleted on a mismatch"
    end

    test "custom exercises survive a legacy reset" do
      ResetCatalog.call(scope: :legacy, expected_exercises: legacy_count)

      assert Exercise.exists?(exercises(:custom_exercise).id)
    end

    test "provider exercises survive a legacy reset, keeping their ids" do
      provider = exercises(:provider_situp)

      ResetCatalog.call(scope: :legacy, expected_exercises: legacy_count)

      assert Exercise.exists?(provider.id)
    end

    test "the destroy cascade removes dependent rows rather than orphaning them" do
      ResetCatalog.call(scope: :catalog, expected_exercises: Exercise.catalog.count)

      assert_equal 0, WorkoutExercise.where(exercise_id: Exercise.catalog.select(:id)).count
      # Nothing may be left pointing at an exercise that no longer exists.
      assert_empty WorkoutExercise.where.not(exercise_id: Exercise.select(:id))
      assert_empty ExerciseLog.where.not(workout_exercise_id: WorkoutExercise.select(:id))
      assert_empty SetLog.where.not(exercise_log_id: ExerciseLog.select(:id))
    end

    test "is idempotent" do
      ResetCatalog.call(scope: :legacy, expected_exercises: legacy_count)

      result = ResetCatalog.call(scope: :legacy, expected_exercises: 0)

      assert_equal 0, result.deleted
    end

    test "taxonomy survives, so a re-import resolves the same keys" do
      muscles = Muscle.count
      equipment = Equipment.count

      ResetCatalog.call(scope: :catalog, expected_exercises: Exercise.catalog.count)

      assert_equal muscles, Muscle.count
      assert_equal equipment, Equipment.count
    end

    test "users and programs are untouched" do
      users = User.count
      programs = Program.count

      ResetCatalog.call(scope: :catalog, expected_exercises: Exercise.catalog.count)

      assert_equal users, User.count
      assert_equal programs, Program.count
    end
  end
end
