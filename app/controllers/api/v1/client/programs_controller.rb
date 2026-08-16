module Api
  module V1
    module Client
      class ProgramsController < BaseController
        # GET /api/v1/client/programs
        #
        # Renders the assignment, not the bare program: the web client reads
        # status, start_date and notes off each row to show a badge and a
        # subtitle. A prior version flattened this to Program.render(programs),
        # which silently dropped that data and crashed the client app the
        # moment a real assignment existed, since ProgramAssignment is what
        # lib/api/types.ts on the frontend has always declared here.
        def index
          assignments = current_user.program_assignments.where(status: :active).includes(:program)
          render json: ProgramAssignmentBlueprint.render(assignments)
        end

        # GET /api/v1/client/programs/:id
        #
        # assignment_id rides alongside the program payload rather than inside
        # ProgramBlueprint, which is shared with the coach side and has no
        # concept of "assignment". The web client needs it to start a workout
        # session: WorkoutSession belongs_to :program_assignment, and nothing
        # about a workout_id alone identifies which assignment a session
        # belongs to when a client could hold more than one, active or not,
        # against the same program. Before this, the program-detail page had
        # no way to learn the id at all, so its workout links carried no
        # assignment_id, every session create defaulted it to 0, and the
        # server correctly rejected it: "Program assignment must exist". No
        # client could complete a single workout.
        def show
          assignment = current_user.program_assignments.find_by!(program_id: params[:id])
          payload = ProgramBlueprint.render_as_hash(assignment.program, view: :extended)
          render json: payload.merge(assignment_id: assignment.id)
        end
      end
    end
  end
end
