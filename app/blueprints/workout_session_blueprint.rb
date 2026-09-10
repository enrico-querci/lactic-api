class WorkoutSessionBlueprint < Blueprinter::Base
  identifier :id
  fields :workout_id, :started_at, :completed_at, :notes

  field :workout_name do |session, _options|
    session.workout.name
  end

  view :extended do
    association :exercise_logs, blueprint: ExerciseLogBlueprint, view: :extended
  end
end
