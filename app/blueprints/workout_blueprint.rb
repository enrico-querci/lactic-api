class WorkoutBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :day

  field :volume_sets

  view :extended do
    association :workout_exercises, blueprint: WorkoutExerciseBlueprint
  end
end
