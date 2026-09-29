module Api
  module V1
    module Client
      class AccountController < BaseController
        # DELETE /api/v1/client/account
        def destroy
          # Before the destroy, which takes the stored token with it. Never
          # blocks the deletion: see Auth::AppleAuthorization.
          Auth::AppleAuthorization.revoke(current_user)
          current_user.destroy!
          head :no_content
        end
      end
    end
  end
end
