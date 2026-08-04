module Api
  module V1
    class ClientInvitationsController < BaseController
      skip_before_action :authenticate!, only: :show

      # GET /api/v1/client_invitations/:token
      def show
        invitation = find_invitation
        render json: ClientInvitationBlueprint.render(invitation)
      end

      # POST /api/v1/client_invitations/:token/accept
      def accept
        invitation = find_invitation
        ClientInvitations::Accept.call(invitation: invitation, user: current_user)
        render json: UserBlueprint.render(current_user.reload)
      rescue ClientInvitations::Accept::AcceptanceError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def find_invitation
        ClientInvitation.find_by_token(params[:token]) || raise(ActiveRecord::RecordNotFound)
      end
    end
  end
end
