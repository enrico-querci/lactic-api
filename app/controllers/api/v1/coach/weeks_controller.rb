module Api
  module V1
    module Coach
      class WeeksController < BaseController
        before_action :set_program

        # GET /api/v1/coach/programs/:program_id/weeks
        def index
          render json: WeekBlueprint.render(@program.weeks)
        end

        # GET /api/v1/coach/programs/:program_id/weeks/:id
        def show
          week = @program.weeks.find(params[:id])
          render json: WeekBlueprint.render(week, view: :extended)
        end

        # POST /api/v1/coach/programs/:program_id/weeks
        def create
          week = @program.weeks.create!(week_params)
          render json: WeekBlueprint.render(week), status: :created
        end

        # PATCH /api/v1/coach/programs/:program_id/weeks/:id
        def update
          week = @program.weeks.find(params[:id])
          week.update!(week_params)
          render json: WeekBlueprint.render(week)
        end

        # DELETE /api/v1/coach/programs/:program_id/weeks/:id
        def destroy
          week = @program.weeks.find(params[:id])
          week.destroy!
          head :no_content
        end

        private

        def set_program
          @program = current_user.programs.find(params[:program_id])
        end

        def week_params
          params.require(:week).permit(:position)
        end
      end
    end
  end
end
