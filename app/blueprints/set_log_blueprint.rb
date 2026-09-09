class SetLogBlueprint < Blueprinter::Base
  identifier :id
  fields :position, :weight_kg, :reps

  view :history do
    field :workout_session_id do |set_log, _options|
      set_log.exercise_log.workout_session_id
    end

    field :performed_at do |set_log, _options|
      session = set_log.exercise_log.workout_session
      session.completed_at || session.started_at
    end
  end
end
