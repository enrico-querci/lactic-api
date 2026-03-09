class WeekBlueprint < Blueprinter::Base
  identifier :id
  field :position

  view :extended do
    association :workouts, blueprint: WorkoutBlueprint
  end
end
