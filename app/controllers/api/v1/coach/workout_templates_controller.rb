module Api
  module V1
    module Coach
      class WorkoutTemplatesController < BaseController
        include Localizable

        # GET /api/v1/coach/workout_templates
        def index
          templates = current_user.workout_templates.includes(:workout_template_exercises)
          render json: WorkoutTemplateBlueprint.render(templates)
        end

        # GET /api/v1/coach/workout_templates/:id
        def show
          template = current_user.workout_templates.find(params[:id])
          render json: WorkoutTemplateBlueprint.render(template, view: :extended, locale: current_locale)
        end

        # POST /api/v1/coach/workout_templates
        #
        # Three ways to start a template:
        # - with `source_workout_id`, as a copy of that workout's exercises;
        # - with `workout_exercises`, holding that list;
        # - with neither, empty.
        # The name and the exercises are written together, so a list that
        # fails validation leaves no template behind.
        def create
          template = if params[:source_workout_id].present?
            workout = Workout.joins(week: :program)
                            .where(programs: { coach_id: current_user.id })
                            .find(params[:source_workout_id])
            WorkoutTemplateBuilder.call(coach: current_user, name: params[:name], workout: workout)
          else
            ApplicationRecord.transaction do
              created = current_user.workout_templates.create!(name: params[:name])
              replace_exercises(created) if params.key?(:workout_exercises)
              created
            end
          end
          render json: WorkoutTemplateBlueprint.render(template, view: :extended, locale: current_locale),
                 status: :created
        end

        # PATCH /api/v1/coach/workout_templates/:id
        #
        # Renames (`name`) and/or replaces the exercises (`workout_exercises`,
        # the complete list as it should be after saving). Each part is applied
        # only when its key is present, and together or not at all.
        def update
          template = current_user.workout_templates.find(params[:id])
          ApplicationRecord.transaction do
            template.update!(name: params[:name]) if params.key?(:name)
            replace_exercises(template) if params.key?(:workout_exercises)
          end
          render json: WorkoutTemplateBlueprint.render(template.reload, view: :extended, locale: current_locale)
        end

        # DELETE /api/v1/coach/workout_templates/:id
        def destroy
          template = current_user.workout_templates.find(params[:id])
          template.destroy!
          head :no_content
        end

        # POST /api/v1/coach/workout_templates/:id/apply
        def apply
          template = current_user.workout_templates.find(params[:id])
          target_week = Week.joins(:program)
                           .where(programs: { coach_id: current_user.id })
                           .find(params[:target_week_id])

          workout = WorkoutTemplateApplier.call(
            template: template,
            target_week: target_week,
            day: params[:day].to_i
          )
          render json: WorkoutBlueprint.render(workout, view: :extended, locale: current_locale), status: :created
        end

        private

        # An absent or empty list clears the template; a missing key never
        # reaches here.
        def replace_exercises(template)
          items = params.permit(
            workout_exercises: %i[exercise_id sets reps rest_seconds rir weight notes]
          )[:workout_exercises] || []
          WorkoutTemplateExerciseReplacer.call(
            template: template, coach: current_user, items: items.map { |item| item.to_h.with_indifferent_access }
          )
        end
      end
    end
  end
end
