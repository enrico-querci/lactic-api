class ExerciseBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :muscle_group, :is_custom, :video_url, :thumbnail_url
end
