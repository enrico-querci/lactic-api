# Adds a template's exercises to a week as a brand-new workout. The result is
# an independent copy: applying the same template on Monday, Wednesday and
# Friday, or for two different clients, yields workouts that can then be
# edited separately.
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
    ActiveRecord::Base.transaction do
      workout = @target_week.workouts.create!(name: @template.name, day: @day)

      @template.workout_template_exercises.each do |template_exercise|
        workout.workout_exercises.create!(
          template_exercise.attributes.slice(*WorkoutTemplateExercise::PRESCRIPTION_ATTRIBUTES)
        )
      end

      workout
    end
  end
end
