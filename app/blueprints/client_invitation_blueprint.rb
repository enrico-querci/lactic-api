class ClientInvitationBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :status, :expires_at, :sent_at, :created_at

  field :coach_name do |invitation|
    invitation.coach.name
  end
end
