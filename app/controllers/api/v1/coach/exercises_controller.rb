module Api
  module V1
    module Coach
      class ExercisesController < BaseController
        # GET /api/v1/coach/exercises
        def index
          exercises = Exercise.for_coach(current_user.id)
          exercises = exercises.where(muscle_group: params[:muscle_group]) if params[:muscle_group].present?
          exercises = exercises.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
          render json: ExerciseBlueprint.render(exercises)
        end

        # POST /api/v1/coach/exercises
        def create
          exercise = current_user.exercises.create!(exercise_params.merge(is_custom: true))
          render json: ExerciseBlueprint.render(exercise), status: :created
        end

        # PATCH /api/v1/coach/exercises/:id
        def update
          exercise = current_user.exercises.find(params[:id])
          exercise.update!(exercise_params)
          render json: ExerciseBlueprint.render(exercise)
        end

        # DELETE /api/v1/coach/exercises/:id
        def destroy
          exercise = current_user.exercises.find(params[:id])
          exercise.destroy!
          head :no_content
        end

        private

        def exercise_params
          params.require(:exercise).permit(:name, :muscle_group, :video_url, :thumbnail_url)
        end
      end
    end
  end
end
