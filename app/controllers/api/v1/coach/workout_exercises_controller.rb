module Api
  module V1
    module Coach
      class WorkoutExercisesController < BaseController
        before_action :set_workout

        # GET /api/v1/coach/workouts/:workout_id/workout_exercises
        def index
          render json: WorkoutExerciseBlueprint.render(@workout.workout_exercises)
        end

        # POST /api/v1/coach/workouts/:workout_id/workout_exercises
        def create
          we = @workout.workout_exercises.create!(workout_exercise_params)
          render json: WorkoutExerciseBlueprint.render(we), status: :created
        end

        # PATCH /api/v1/coach/workouts/:workout_id/workout_exercises/:id
        def update
          we = @workout.workout_exercises.find(params[:id])
          we.update!(workout_exercise_params)
          render json: WorkoutExerciseBlueprint.render(we)
        end

        # DELETE /api/v1/coach/workouts/:workout_id/workout_exercises/:id
        def destroy
          we = @workout.workout_exercises.find(params[:id])
          we.destroy!
          head :no_content
        end

        private

        def set_workout
          @workout = Workout.joins(week: :program)
                           .where(programs: { coach_id: current_user.id })
                           .find(params[:workout_id])
        end

        def workout_exercise_params
          params.require(:workout_exercise).permit(
            :exercise_id, :position, :sets, :reps, :rest_seconds, :rir, :weight, :notes
          )
        end
      end
    end
  end
end
