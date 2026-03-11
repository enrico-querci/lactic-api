module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate!, only: %i[create refresh destroy dev_login]

      # POST /api/v1/auth
      def create
        result = Auth::Authenticate.call(
          provider: params[:provider],
          id_token: params[:id_token],
          role: params[:role]
        )
        render json: {
          access_token: result[:access_token],
          refresh_token: result[:refresh_token],
          user: user_json(result[:user])
        }
      rescue Auth::VerificationError => e
        render json: { error: e.message }, status: :unauthorized
      end

      # POST /api/v1/auth/refresh
      def refresh
        result = Auth::Refresh.call(refresh_token: params[:refresh_token])
        render json: {
          access_token: result[:access_token],
          refresh_token: result[:refresh_token]
        }
      rescue Auth::TokenError => e
        render json: { error: e.message }, status: :unauthorized
      end

      # DELETE /api/v1/auth
      def destroy
        Auth::Logout.call(refresh_token: params[:refresh_token])
        head :no_content
      end

      # POST /api/v1/auth/dev_login (dev/test ONLY — triple protected)
      def dev_login
        raise ActionController::RoutingError, "Not Found" unless Rails.env.development? || Rails.env.test?

        user = User.find_by!(email: params[:email])
        access_token = JwtService.encode(user_id: user.id)
        refresh = user.refresh_tokens.create!(
          token: SecureRandom.hex(32),
          expires_at: JwtService::REFRESH_TOKEN_EXPIRY.from_now
        )

        render json: {
          access_token: access_token,
          refresh_token: refresh.token,
          user: user_json(user)
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      private

      def user_json(user)
        { id: user.id, name: user.name, email: user.email, role: user.role }
      end
    end
  end
end
