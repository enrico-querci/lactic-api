class ProgramAssignmentBlueprint < Blueprinter::Base
  identifier :id
  fields :start_date, :status, :notes

  association :program, blueprint: ProgramBlueprint
  association :client, blueprint: UserBlueprint
end
