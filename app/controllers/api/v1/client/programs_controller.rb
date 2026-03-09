module Api
  module V1
    module Client
      class ProgramsController < BaseController
        # GET /api/v1/client/programs
        def index
          assignments = current_user.program_assignments.where(status: :active).includes(:program)
          programs = assignments.map(&:program)
          render json: ProgramBlueprint.render(programs)
        end

        # GET /api/v1/client/programs/:id
        def show
          assignment = current_user.program_assignments.find_by!(program_id: params[:id])
          render json: ProgramBlueprint.render(assignment.program, view: :extended)
        end
      end
    end
  end
end
