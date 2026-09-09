module Api
  module V1
    module Coach
      class ClientProgressController < BaseController
        include Localizable

        before_action :set_client

        # GET /api/v1/coach/clients/:client_id/progress
        def index
          sessions = @client.workout_sessions
                           .includes(:workout)
                           .joins(program_assignment: :program)
                           .where(programs: { coach_id: current_user.id })
                           .order(started_at: :desc)
          render json: WorkoutSessionBlueprint.render(sessions, locale: current_locale)
        end

        # GET /api/v1/coach/clients/:client_id/progress/:id
        def show
          session = @client.workout_sessions
                          .includes(:workout, exercise_logs: [ :set_logs, { workout_exercise: :exercise } ])
                          .joins(program_assignment: :program)
                          .where(programs: { coach_id: current_user.id })
                          .find(params[:id])
          render json: WorkoutSessionBlueprint.render(session, view: :extended, locale: current_locale)
        end

        private

        def set_client
          @client = current_user.clients.find(params[:client_id])
        end
      end
    end
  end
end
