module Api
  module V1
    module Client
      class WorkoutSessionsController < BaseController
        include Localizable

        # GET /api/v1/client/workout_sessions
        def index
          sessions = current_user.workout_sessions.includes(:workout).order(started_at: :desc)
          render json: WorkoutSessionBlueprint.render(sessions, locale: current_locale)
        end

        # GET /api/v1/client/workout_sessions/:id
        def show
          session = current_user.workout_sessions
                                .includes(:workout, exercise_logs: [ :set_logs, { workout_exercise: :exercise } ])
                                .find(params[:id])
          render json: WorkoutSessionBlueprint.render(session, view: :extended, locale: current_locale)
        end

        # POST /api/v1/client/workout_sessions
        def create
          session = current_user.workout_sessions.create!(session_params)
          render json: WorkoutSessionBlueprint.render(session, locale: current_locale), status: :created
        end

        # PATCH /api/v1/client/workout_sessions/:id
        def update
          session = current_user.workout_sessions.find(params[:id])
          session.update!(session_params)
          render json: WorkoutSessionBlueprint.render(session, locale: current_locale)
        end

        private

        def session_params
          params.require(:workout_session).permit(:workout_id, :program_assignment_id, :started_at, :completed_at, :notes)
        end
      end
    end
  end
end
