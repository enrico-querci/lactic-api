require "test_helper"

class ClientInvitationMailerTest < ActionMailer::TestCase
  test "invitation email contains the accepting link and recipient" do
    invitation = ClientInvitation.create!(coach: users(:coach_john), email: "mail@example.com")
    mail = ClientInvitationMailer.with(invitation: invitation, token: invitation.raw_token).invitation_email

    assert_equal [ invitation.email ], mail.to
    assert_match users(:coach_john).name, mail.subject
    assert_match "/invite/#{invitation.raw_token}", mail.html_part.body.decoded
    assert_match invitation.email, mail.text_part.body.decoded
  end
end
