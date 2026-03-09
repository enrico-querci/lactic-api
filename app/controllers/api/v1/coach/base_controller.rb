module Api
  module V1
    module Coach
      class BaseController < Api::V1::BaseController
        before_action :require_coach!
      end
    end
  end
end
