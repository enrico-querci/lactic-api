module Catalog
  # Deletes catalog exercises so a provider import can replace them.
  #
  # The dangerous operation in the whole plan, so the guards are deliberate
  # rather than ceremonial:
  #
  #   * the caller must pass the exercise count it expects to delete. If the
  #     data changed since the plan was reviewed, the numbers disagree and this
  #     refuses. That closes the gap between "I read the report" and "I ran the
  #     command", which on a shared database can be hours.
  #   * coach-owned custom exercises are excluded unless the scope explicitly
  #     says otherwise. They are a coach's own work, not catalog content.
  #   * everything happens in one transaction, so a failure half way leaves the
  #     catalog as it was rather than partially deleted.
  #   * it is idempotent: running it twice deletes nothing the second time,
  #     because there is nothing left in scope.
  class ResetCatalog
    class CountMismatch < StandardError; end

    Result = Data.define(:deleted, :report)

    def self.call(...) = new(...).call

    def initialize(scope: :legacy, expected_exercises:)
      @scope = scope.to_sym
      @expected = expected_exercises
    end

    def call
      plan = ResetPlan.new(scope: @scope)
      report = plan.call

      unless report.exercises == @expected
        raise CountMismatch,
          "expected to delete #{@expected} exercises but found #{report.exercises}. " \
          "Re-run the plan and confirm the new number."
      end

      deleted = 0
      ActiveRecord::Base.transaction do
        # destroy_all rather than delete_all: the dependent: :destroy chain is
        # what removes workout_exercises, exercise_logs and set_logs. delete_all
        # would skip it and leave orphaned rows pointing at nothing.
        deleted = plan.target.destroy_all.size
      end

      Rails.logger.warn(
        "catalog_reset scope=#{@scope} deleted_exercises=#{deleted} " \
        "set_logs=#{report.set_logs} workout_exercises=#{report.workout_exercises}"
      )

      Result.new(deleted: deleted, report: report)
    end
  end
end
