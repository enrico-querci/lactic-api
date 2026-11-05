# `invitations` (email => pending invitation), passed by the caller, lets a
# whole list be serialized with one query rather than one per profile.
class ClientProfileBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :email, :phone, :level, :goal, :limitations, :notes, :user_id, :created_at

  field :status do |profile, options|
    if profile.linked?
      "active"
    elsif options[:invitations]&.key?(profile.email)
      "invited"
    else
      "prepared"
    end
  end

  field :invitation_id do |profile, options|
    options[:invitations]&.dig(profile.email)&.id unless profile.linked?
  end

  field :invitation_expires_at do |profile, options|
    options[:invitations]&.dig(profile.email)&.expires_at unless profile.linked?
  end
end
