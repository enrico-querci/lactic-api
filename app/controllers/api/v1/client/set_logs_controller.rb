module Api
  module V1
    module Client
      class SetLogsController < BaseController
        # POST /api/v1/client/set_logs
        def create
          log = owned_exercise_log(params[:set_log][:exercise_log_id])
          set_log = log.set_logs.create!(set_log_params)
          render json: SetLogBlueprint.render(set_log), status: :created
        end

        # PATCH /api/v1/client/set_logs/:id
        def update
          set_log = owned_set_logs.find(params[:id])
          set_log.update!(set_log_params)
          render json: SetLogBlueprint.render(set_log)
        end

        # DELETE /api/v1/client/set_logs/:id
        def destroy
          set_log = owned_set_logs.find(params[:id])
          set_log.destroy!
          head :no_content
        end

        private

        def owned_exercise_log(exercise_log_id)
          ExerciseLog.joins(:workout_session)
                    .where(workout_sessions: { client_id: current_user.id })
                    .find(exercise_log_id)
        end

        def owned_set_logs
          SetLog.joins(exercise_log: :workout_session)
               .where(workout_sessions: { client_id: current_user.id })
        end

        def set_log_params
          params.require(:set_log).permit(:exercise_log_id, :position, :weight_kg, :reps)
        end
      end
    end
  end
end
