module Api
  module V1
    module Coach
      class DashboardController < BaseController
        # GET /api/v1/coach/dashboard
        def show
          render json: CoachDashboard.call(coach: current_user)
        end
      end
    end
  end
end
