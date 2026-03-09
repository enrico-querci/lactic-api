module Api
  module V1
    class MeController < BaseController
      # GET /api/v1/me
      def show
        render json: UserBlueprint.render(current_user)
      end

      # PATCH /api/v1/me
      def update
        current_user.update!(me_params)
        render json: UserBlueprint.render(current_user)
      end

      private

      def me_params
        params.require(:user).permit(:name, :avatar_url)
      end
    end
  end
end
