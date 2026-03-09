module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        before_action :require_client!
      end
    end
  end
end
