class ExerciseLogBlueprint < Blueprinter::Base
  identifier :id
  fields :workout_exercise_id, :notes, :photo_url

  field :exercise_id do |log, _options|
    log.workout_exercise.exercise_id
  end

  field :exercise_name do |log, options|
    log.workout_exercise.exercise.localized_name(options[:locale])
  end

  field :position do |log, _options|
    log.workout_exercise.position
  end

  view :extended do
    association :set_logs, blueprint: SetLogBlueprint
  end
end
