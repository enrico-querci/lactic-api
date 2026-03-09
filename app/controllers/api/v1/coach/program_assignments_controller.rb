module Api
  module V1
    module Coach
      class ProgramAssignmentsController < BaseController
        # GET /api/v1/coach/program_assignments
        def index
          assignments = ProgramAssignment.where(coach: current_user)
          assignments = assignments.where(client_id: params[:client_id]) if params[:client_id].present?
          assignments = assignments.where(status: params[:status]) if params[:status].present?
          render json: ProgramAssignmentBlueprint.render(assignments)
        end

        # GET /api/v1/coach/program_assignments/:id
        def show
          assignment = ProgramAssignment.where(coach: current_user).find(params[:id])
          render json: ProgramAssignmentBlueprint.render(assignment)
        end

        # POST /api/v1/coach/program_assignments
        def create
          assignment = ProgramAssignment.create!(assignment_params.merge(coach: current_user))
          render json: ProgramAssignmentBlueprint.render(assignment), status: :created
        end

        # PATCH /api/v1/coach/program_assignments/:id
        def update
          assignment = ProgramAssignment.where(coach: current_user).find(params[:id])
          assignment.update!(assignment_params)
          render json: ProgramAssignmentBlueprint.render(assignment)
        end

        # DELETE /api/v1/coach/program_assignments/:id
        def destroy
          assignment = ProgramAssignment.where(coach: current_user).find(params[:id])
          assignment.destroy!
          head :no_content
        end

        private

        def assignment_params
          params.require(:program_assignment).permit(:program_id, :client_id, :start_date, :status, :notes)
        end
      end
    end
  end
end
