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
          render json: WorkoutTemplateBlueprint.render(template)
        end

        # POST /api/v1/coach/workout_templates
        def create
          workout = Workout.joins(week: :program)
                          .where(programs: { coach_id: current_user.id })
                          .find(params[:source_workout_id])

          template = WorkoutTemplateBuilder.call(coach: current_user, name: params[:name], workout: workout)
          render json: WorkoutTemplateBlueprint.render(template), status: :created
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
      end
    end
  end
end
