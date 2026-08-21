class WorkoutBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :day

  # Note: :extended nests workout_exercises -> exercise (ExerciseBlueprint),
  # whose #name already localizes via Exercise#localized_name. Passing
  # `locale:` here to reach volume_sets therefore also localizes those
  # nested exercise names wherever an `it` exercise_translations row
  # exists — inert in production today (zero such rows, no translation
  # credential configured), but real once translations land. Not blocked
  # here on purpose: coach/exercises_controller already localizes names
  # directly, so suppressing it only for nested workout exercises would be
  # the inconsistent choice.
  field :volume_sets do |workout, options|
    Catalog::Translation::TaxonomyLabels.volume_sets(workout.volume_sets, options[:locale])
  end

  view :extended do
    association :workout_exercises, blueprint: WorkoutExerciseBlueprint
  end
end
