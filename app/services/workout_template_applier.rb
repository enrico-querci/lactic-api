class WorkoutTemplateApplier
  def self.call(template:, target_week:, day:)
    new(template, target_week, day).call
  end

  def initialize(template, target_week, day)
    @template = template
    @target_week = target_week
    @day = day
  end

  def call
    source = @template.source_workout
    WorkoutDuplicator.call(workout: source, target_week: @target_week, day: @day)
  end
end
