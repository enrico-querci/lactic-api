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

          # `reorder`, not `order`: SetLog includes Positionable, whose
          # `default_scope { order(position: :asc) }` is applied FIRST and would
          # otherwise win. `order` only appends, producing
          #   ORDER BY set_logs.position ASC, workout_sessions.started_at DESC, ...
          # which sorts by set number and interleaves every session together —
          # so "most recent first" silently did nothing and the client's
          # exercise history read as a jumble across dates.
          set_logs = SetLog.joins(exercise_log: { workout_session: {}, workout_exercise: {} })
                          .where(workout_sessions: { client_id: current_user.id })
                          .where(workout_exercises: { exercise_id: exercise.id })
                          .reorder("workout_sessions.started_at DESC, set_logs.position ASC")

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
