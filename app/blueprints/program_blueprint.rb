class ProgramBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :description, :created_at

  view :extended do
    association :weeks, blueprint: WeekBlueprint, view: :extended
  end
end
