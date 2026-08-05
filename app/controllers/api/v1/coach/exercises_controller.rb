module Api
  module V1
    module Coach
      class ExercisesController < BaseController
        include Localizable
        include Paginatable

        SEARCH_PARAMS = %i[
          search muscle primary_muscle equipment category difficulty custom
          muscle_group page per_page
        ].freeze

        # GET /api/v1/coach/exercises
        #
        # Defaults to what a coach may actually put into a workout: active and
        # assignable. `include_unassignable=true` widens it, so a coach can
        # still find a retired exercise that a program already references.
        def index
          result = Catalog::ExerciseSearch.call(scope: index_scope, params: search_params)

          apply_pagination_headers(result)
          render json: ExerciseBlueprint.render(result.records, locale: current_locale)
        end

        # GET /api/v1/coach/exercises/:id
        #
        # Uses `for_coach` rather than `selectable`, so an exercise a program
        # already references keeps resolving after it is deactivated.
        def show
          exercise = Exercise.for_coach(current_user.id).find(params[:id])
          render json: ExerciseBlueprint.render(exercise, view: :detail, locale: current_locale)
        end

        # POST /api/v1/coach/exercises
        def create
          exercise = current_user.exercises.create!(exercise_params.merge(is_custom: true))
          render json: ExerciseBlueprint.render(exercise, view: :detail, locale: current_locale), status: :created
        end

        # PATCH /api/v1/coach/exercises/:id
        def update
          exercise = current_user.exercises.find(params[:id])
          exercise.update!(exercise_params)
          render json: ExerciseBlueprint.render(exercise, view: :detail, locale: current_locale)
        end

        # DELETE /api/v1/coach/exercises/:id
        def destroy
          exercise = current_user.exercises.find(params[:id])
          exercise.destroy!
          head :no_content
        end

        private

        def index_scope
          if params[:include_unassignable].to_s == "true"
            Exercise.for_coach(current_user.id)
          else
            Exercise.selectable(current_user.id)
          end
        end

        def search_params
          params.permit(*SEARCH_PARAMS).to_h.symbolize_keys
        end

        def exercise_params
          params.require(:exercise).permit(:name, :muscle_group, :video_url, :thumbnail_url)
        end
      end
    end
  end
end
