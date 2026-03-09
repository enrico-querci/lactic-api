module Api
  module V1
    module Client
      class ExerciseLogsController < BaseController
        # POST /api/v1/client/exercise_logs
        def create
          session = current_user.workout_sessions.find(params[:exercise_log][:workout_session_id])
          log = session.exercise_logs.create!(exercise_log_params)
          render json: ExerciseLogBlueprint.render(log), status: :created
        end

        # PATCH /api/v1/client/exercise_logs/:id
        def update
          log = ExerciseLog.joins(:workout_session)
                          .where(workout_sessions: { client_id: current_user.id })
                          .find(params[:id])
          log.update!(exercise_log_params)
          render json: ExerciseLogBlueprint.render(log)
        end

        private

        def exercise_log_params
          params.require(:exercise_log).permit(:workout_session_id, :workout_exercise_id, :notes, :photo_url)
        end
      end
    end
  end
end
