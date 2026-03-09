module Api
  module V1
    module Client
      class WorkoutsController < BaseController
        # GET /api/v1/client/workouts/:id
        def show
          workout = accessible_workouts.find(params[:id])
          render json: WorkoutBlueprint.render(workout, view: :extended)
        end

        private

        def accessible_workouts
          Workout.joins(week: { program: :program_assignments })
                 .where(program_assignments: { client_id: current_user.id })
        end
      end
    end
  end
end
