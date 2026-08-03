class ClientInvitationMailer < ApplicationMailer
  def invitation_email
    @invitation = params[:invitation]
    @coach = @invitation.coach
    @acceptance_url = "#{frontend_url}/invite/#{params[:token]}"

    Rails.logger.info("Client invitation URL: #{@acceptance_url}") if Rails.env.development?

    mail(
      to: @invitation.email,
      subject: "#{@coach.name} invited you to Lactic"
    )
  end

  private

  def frontend_url
    ENV.fetch("FRONTEND_URL", "http://localhost:3001").delete_suffix("/")
  end
end
