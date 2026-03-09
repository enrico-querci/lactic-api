class WorkoutTemplateBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :source_workout_id, :created_at
end
