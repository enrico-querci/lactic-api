class ExerciseLogBlueprint < Blueprinter::Base
  identifier :id
  fields :workout_exercise_id, :notes, :photo_url

  view :extended do
    association :set_logs, blueprint: SetLogBlueprint
  end
end
