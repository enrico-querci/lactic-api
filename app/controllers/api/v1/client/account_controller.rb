module Api
  module V1
    module Client
      class AccountController < BaseController
        # DELETE /api/v1/client/account
        def destroy
          current_user.destroy!
          head :no_content
        end
      end
    end
  end
end
