class WorkoutTemplateBlueprint < Blueprinter::Base
  identifier :id
  # source_workout_id is null once the workout the template was saved from
  # has been deleted.
  fields :name, :source_workout_id, :created_at

  # `.size` rather than `.count` so a controller that preloads the
  # exercises serializes a whole list without a query per template.
  field :exercise_count do |template|
    template.workout_template_exercises.size
  end
end
