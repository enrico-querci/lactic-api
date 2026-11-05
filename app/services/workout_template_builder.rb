# Saves a workout as a reusable template by copying its exercises, so the
# template stays as it was saved no matter what happens to the workout later.
class WorkoutTemplateBuilder
  def self.call(coach:, name:, workout:)
    new(coach, name, workout).call
  end

  def initialize(coach, name, workout)
    @coach = coach
    @name = name
    @workout = workout
  end

  def call
    ActiveRecord::Base.transaction do
      template = @coach.workout_templates.create!(name: @name, source_workout: @workout)

      @workout.workout_exercises.each do |workout_exercise|
        template.workout_template_exercises.create!(
          workout_exercise.attributes.slice(*WorkoutTemplateExercise::PRESCRIPTION_ATTRIBUTES)
        )
      end

      template
    end
  end
end
