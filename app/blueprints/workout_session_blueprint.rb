class WorkoutSessionBlueprint < Blueprinter::Base
  identifier :id
  fields :workout_id, :started_at, :completed_at, :notes

  view :extended do
    association :exercise_logs, blueprint: ExerciseLogBlueprint, view: :extended
  end
end
