class WorkoutExerciseBlueprint < Blueprinter::Base
  identifier :id
  fields :position, :sets, :reps, :rest_seconds, :rir, :weight, :notes

  association :exercise, blueprint: ExerciseBlueprint
end
