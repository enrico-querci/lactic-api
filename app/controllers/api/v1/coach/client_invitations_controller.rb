module Api
  module V1
    module Coach
      class ClientInvitationsController < BaseController
        # GET /api/v1/coach/client_invitations
        def index
          invitations = current_user.client_invitations.pending.recent_first
          render json: ClientInvitationBlueprint.render(invitations)
        end

        # POST /api/v1/coach/client_invitations
        def create
          email = normalized_email
          return unless invitable?(email)
          return unless email_delivery_configured?

          invitation = current_user.client_invitations.pending.find_or_initialize_by(email: email)
          token = invitation.persisted? ? invitation.renew! : create_invitation!(invitation)
          return unless deliver_invitation(invitation, token)

          render json: ClientInvitationBlueprint.render(invitation), status: :created
        end

        # POST /api/v1/coach/client_invitations/:id/resend
        def resend_invitation
          return unless email_delivery_configured?

          invitation = current_user.client_invitations.pending.find(params[:id])
          token = invitation.renew!
          return unless deliver_invitation(invitation, token)

          render json: ClientInvitationBlueprint.render(invitation)
        end

        # DELETE /api/v1/coach/client_invitations/:id
        def destroy
          invitation = current_user.client_invitations.pending.find(params[:id])
          invitation.revoke!
          head :no_content
        end

        private

        def normalized_email
          params.require(:email).to_s.strip.downcase
        end

        def create_invitation!(invitation)
          invitation.save!
          invitation.raw_token
        end

        def invitable?(email)
          user = User.where("LOWER(email) = ?", email).first
          return true unless user
          return true if user.client? && user.coach_id.nil?

          if user.coach?
            render json: { error: "A coach account cannot be invited as a client" }, status: :unprocessable_entity
          elsif user.coach_id == current_user.id
            render json: { error: "This person is already your client" }, status: :unprocessable_entity
          elsif user.coach_id.present?
            render json: { error: "This person already belongs to another coach" }, status: :conflict
          end

          false
        end

        def email_delivery_configured?
          return true unless Rails.env.production?
          required_variables = %w[RESEND_API_KEY FRONTEND_URL MAIL_FROM]
          return true if required_variables.all? { |name| ENV[name].present? }

          render json: { error: "Email delivery is not configured" }, status: :service_unavailable
          false
        end

        def deliver_invitation(invitation, token)
          ClientInvitationMailer.with(invitation: invitation, token: token).invitation_email.deliver_now
          invitation.mark_sent!
          true
        rescue StandardError => e
          Rails.logger.error("Client invitation email failed: #{e.class}: #{e.message}")
          render json: { error: "The invitation was saved, but the email could not be sent" }, status: :service_unavailable
          false
        end
      end
    end
  end
end
