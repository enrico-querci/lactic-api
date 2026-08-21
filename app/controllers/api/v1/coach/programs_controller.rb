module Api
  module V1
    module Coach
      class ProgramsController < BaseController
        include Localizable

        # GET /api/v1/coach/programs
        def index
          programs = current_user.programs
          render json: ProgramBlueprint.render(programs, locale: current_locale)
        end

        # GET /api/v1/coach/programs/:id
        def show
          program = current_user.programs.find(params[:id])
          render json: ProgramBlueprint.render(program, view: :extended, locale: current_locale)
        end

        # POST /api/v1/coach/programs
        def create
          program = current_user.programs.create!(program_params)
          render json: ProgramBlueprint.render(program, locale: current_locale), status: :created
        end

        # PATCH /api/v1/coach/programs/:id
        def update
          program = current_user.programs.find(params[:id])
          program.update!(program_params)
          render json: ProgramBlueprint.render(program, locale: current_locale)
        end

        # DELETE /api/v1/coach/programs/:id
        def destroy
          program = current_user.programs.find(params[:id])
          program.destroy!
          head :no_content
        end

        private

        def program_params
          params.require(:program).permit(:name, :description)
        end
      end
    end
  end
end
