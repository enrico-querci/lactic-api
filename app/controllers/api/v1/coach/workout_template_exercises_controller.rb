module Api
  module V1
    module Coach
      # The exercises of one workout template, with the same verbs and JSON
      # shape as a workout's own (WorkoutExercisesController).
      class WorkoutTemplateExercisesController < BaseController
        include Localizable

        before_action :set_template

        # GET /api/v1/coach/workout_templates/:workout_template_id/workout_exercises
        def index
          exercises = @template.workout_template_exercises.includes(:exercise)
          render json: WorkoutExerciseBlueprint.render(exercises, locale: current_locale)
        end

        # POST /api/v1/coach/workout_templates/:workout_template_id/workout_exercises
        #
        # `position` is optional: the next free letter is used when it is left
        # out. The exercise must be one the coach could pick for a workout
        # (their own or the active, assignable catalog), so a template cannot
        # hold an exercise the picker would never have offered.
        def create
          exercise = Exercise.selectable(current_user.id).find(workout_exercise_params[:exercise_id])
          template_exercise = @template.workout_template_exercises.create!(
            prescription_params.merge(exercise: exercise)
          )
          render json: WorkoutExerciseBlueprint.render(template_exercise, locale: current_locale), status: :created
        end

        # PATCH /api/v1/coach/workout_templates/:workout_template_id/workout_exercises/:id
        #
        # The exercise itself is not changeable: remove it and add another.
        def update
          template_exercise = @template.workout_template_exercises.find(params[:id])
          template_exercise.update!(prescription_params)
          render json: WorkoutExerciseBlueprint.render(template_exercise, locale: current_locale)
        end

        # DELETE /api/v1/coach/workout_templates/:workout_template_id/workout_exercises/:id
        def destroy
          @template.workout_template_exercises.find(params[:id]).destroy!
          head :no_content
        end

        private

        def set_template
          @template = current_user.workout_templates.find(params[:workout_template_id])
        end

        def workout_exercise_params
          params.require(:workout_exercise)
        end

        def prescription_params
          workout_exercise_params.permit(:position, :sets, :reps, :rest_seconds, :rir, :weight, :notes)
        end
      end
    end
  end
end
