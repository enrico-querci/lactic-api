require "test_helper"

module Catalog
  class MergeMuscleAliasesTest < ActiveSupport::TestCase
    setup do
      @canonical = muscles(:abs)
      @exercise = exercises(:provider_situp)
    end

    def duplicate!(key: "abdominals", name: "Abdominals")
      Muscle.create!(key: key, name: name)
    end

    def merge(aliases = { "abdominals" => "abs" })
      MergeMuscleAliases.call(aliases: aliases)
    end

    # --- Re-pointing --------------------------------------------------------

    test "re-points a link from the duplicate onto the canonical muscle" do
      dup = duplicate!
      other = exercises(:provider_treadmill)
      link = ExerciseMuscle.create!(exercise: other, muscle: dup, role: "secondary")

      report = merge

      assert_equal 1, report.relinked
      assert_equal @canonical.id, link.reload.muscle_id
      assert_not Muscle.exists?(dup.id), "the duplicate row must be gone"
    end

    test "keeps the link id so timestamps and references survive" do
      dup = duplicate!
      link = ExerciseMuscle.create!(exercise: exercises(:provider_treadmill), muscle: dup, role: "secondary")

      merge

      assert ExerciseMuscle.exists?(link.id)
    end

    # --- Conflicts ----------------------------------------------------------

    test "drops the duplicate link when the exercise already references the canonical muscle" do
      dup = duplicate!
      # situp already links to abs as primary via the fixtures.
      ExerciseMuscle.create!(exercise: @exercise, muscle: dup, role: "secondary")

      report = merge

      assert_equal 1, report.deduplicated
      assert_equal 0, report.relinked
      # Exactly one link to abs, not two — the unique index would forbid it.
      assert_equal 1, ExerciseMuscle.where(exercise: @exercise, muscle: @canonical).count
    end

    test "the stronger role wins when both links exist" do
      dup = duplicate!
      other = exercises(:provider_treadmill)
      # Clear its fixture primary first: the single-primary rule would reject a
      # second one at setup time, before the merge under test ever runs.
      other.exercise_muscles.destroy_all
      ExerciseMuscle.create!(exercise: other, muscle: @canonical, role: "secondary")
      ExerciseMuscle.create!(exercise: other, muscle: dup, role: "primary")

      report = merge

      assert_equal 1, report.promoted
      assert_equal "primary", ExerciseMuscle.find_by(exercise: other, muscle: @canonical).role
      # Still exactly one primary, so the partial unique index holds.
      assert_equal 1, other.exercise_muscles.where(role: "primary").count
    end

    test "does not demote an existing primary" do
      dup = duplicate!
      ExerciseMuscle.create!(exercise: @exercise, muscle: dup, role: "secondary")

      merge

      assert_equal "primary", ExerciseMuscle.find_by(exercise: @exercise, muscle: @canonical).role
    end

    # --- Edge cases ---------------------------------------------------------

    test "renames the duplicate when no canonical row exists yet" do
      @canonical.exercise_muscles.destroy_all
      @canonical.destroy!
      dup = duplicate!

      merge

      assert_equal "abs", dup.reload.key
    end

    test "is idempotent" do
      duplicate!
      merge

      report = merge

      assert_equal 0, report.merged_muscles
      assert_equal 0, report.relinked
    end

    test "does nothing when there is no duplicate to merge" do
      report = merge

      assert_equal 0, report.merged_muscles
      assert Muscle.exists?(@canonical.id)
    end

    test "leaves muscles that are not aliases alone" do
      distinct = Muscle.create!(key: "core", name: "Core")

      MergeMuscleAliases.call

      assert Muscle.exists?(distinct.id), "core has no canonical equivalent and must survive"
    end

    test "handles every alias in the real table without violating an index" do
      # Builds one duplicate per alias, each attached to an exercise that also
      # references the canonical muscle where one exists — the collision case.
      NormalizeExercise::MUSCLE_ALIASES.each_key do |key|
        Muscle.find_or_create_by!(key: key) { |m| m.name = key.titleize }
      end

      assert_nothing_raised { MergeMuscleAliases.call }

      leftovers = Muscle.where(key: NormalizeExercise::MUSCLE_ALIASES.keys)
      assert_empty leftovers, "no alias key may survive the merge"
    end

    test "reports what it did" do
      duplicate!
      ExerciseMuscle.create!(exercise: exercises(:provider_treadmill), muscle: Muscle.find_by(key: "abdominals"), role: "secondary")

      assert_includes merge.to_s, "duplicate muscles merged"
    end
  end
end
