module Api
  module V1
    module Client
      class ExercisesController < BaseController
        include Localizable
        include Paginatable

        SEARCH_PARAMS = %i[
          search muscle primary_muscle equipment category difficulty
          muscle_group page per_page
        ].freeze

        # GET /api/v1/client/exercises
        #
        # A client sees their coach's catalog. Unlike the coach picker this is
        # not restricted to assignable exercises, because a client's assigned
        # program may legitimately reference one that has since been retired.
        def index
          scope = Exercise.for_coach(current_user.coach_id)
          result = Catalog::ExerciseSearch.call(scope: scope, params: search_params)

          apply_pagination_headers(result)
          render json: ExerciseBlueprint.render(result.records, locale: current_locale)
        end

        # GET /api/v1/client/exercises/:id
        def show
          exercise = Exercise.for_coach(current_user.coach_id).find(params[:id])
          render json: ExerciseBlueprint.render(exercise, view: :detail, locale: current_locale)
        end

        # GET /api/v1/client/exercises/:id/history
        def history
          exercise = Exercise.for_coach(current_user.coach_id).find(params[:id])

          set_logs = SetLog.joins(exercise_log: { workout_session: {}, workout_exercise: {} })
                          .where(workout_sessions: { client_id: current_user.id })
                          .where(workout_exercises: { exercise_id: exercise.id })
                          .order("workout_sessions.started_at DESC, set_logs.position ASC")

          render json: SetLogBlueprint.render(set_logs)
        end

        private

        def search_params
          params.permit(*SEARCH_PARAMS).to_h.symbolize_keys
        end
      end
    end
  end
end
