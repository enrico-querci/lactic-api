module Api
  module V1
    module Coach
      class WorkoutsController < BaseController
        before_action :set_week

        # GET /api/v1/coach/programs/:program_id/weeks/:week_id/workouts
        def index
          render json: WorkoutBlueprint.render(@week.workouts)
        end

        # GET /api/v1/coach/programs/:program_id/weeks/:week_id/workouts/:id
        def show
          workout = @week.workouts.find(params[:id])
          render json: WorkoutBlueprint.render(workout, view: :extended)
        end

        # POST /api/v1/coach/programs/:program_id/weeks/:week_id/workouts
        def create
          workout = @week.workouts.create!(workout_params)
          render json: WorkoutBlueprint.render(workout), status: :created
        end

        # PATCH /api/v1/coach/programs/:program_id/weeks/:week_id/workouts/:id
        def update
          workout = @week.workouts.find(params[:id])
          workout.update!(workout_params)
          render json: WorkoutBlueprint.render(workout)
        end

        # DELETE /api/v1/coach/programs/:program_id/weeks/:week_id/workouts/:id
        def destroy
          workout = @week.workouts.find(params[:id])
          workout.destroy!
          head :no_content
        end

        # POST /api/v1/coach/programs/:program_id/weeks/:week_id/workouts/:id/duplicate
        def duplicate
          workout = @week.workouts.find(params[:id])
          target_week = params[:target_week_id] ? @week.program.weeks.find(params[:target_week_id]) : @week
          new_workout = WorkoutDuplicator.call(workout: workout, target_week: target_week, day: params[:day]&.to_i)
          render json: WorkoutBlueprint.render(new_workout, view: :extended), status: :created
        end

        private

        def set_week
          program = current_user.programs.find(params[:program_id])
          @week = program.weeks.find(params[:week_id])
        end

        def workout_params
          params.require(:workout).permit(:name, :day)
        end
      end
    end
  end
end
