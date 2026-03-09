class UserBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :email, :role, :avatar_url
end
