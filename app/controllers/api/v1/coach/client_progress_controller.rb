module Api
  module V1
    module Coach
      class ClientProgressController < BaseController
        before_action :set_client

        # GET /api/v1/coach/clients/:client_id/progress
        def index
          sessions = @client.workout_sessions
                           .joins(program_assignment: :program)
                           .where(programs: { coach_id: current_user.id })
                           .order(started_at: :desc)
          render json: WorkoutSessionBlueprint.render(sessions)
        end

        # GET /api/v1/coach/clients/:client_id/progress/:id
        def show
          session = @client.workout_sessions
                          .joins(program_assignment: :program)
                          .where(programs: { coach_id: current_user.id })
                          .find(params[:id])
          render json: WorkoutSessionBlueprint.render(session, view: :extended)
        end

        private

        def set_client
          @client = current_user.clients.find(params[:client_id])
        end
      end
    end
  end
end
