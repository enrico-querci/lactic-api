require "test_helper"

class ClientInvitationTest < ActiveSupport::TestCase
  setup do
    @coach = users(:coach_john)
  end

  test "creates a secure token digest and normalizes email" do
    invitation = ClientInvitation.create!(coach: @coach, email: "  NEW.Client@Example.com ")

    assert_equal "new.client@example.com", invitation.email
    assert invitation.raw_token.present?
    assert_equal ClientInvitation.digest(invitation.raw_token), invitation.token_digest
    assert_not_equal invitation.raw_token, invitation.token_digest
    assert_equal invitation, ClientInvitation.find_by_token(invitation.raw_token)
  end

  test "renewing invalidates the previous token" do
    invitation = ClientInvitation.create!(coach: @coach, email: "renew@example.com")
    old_token = invitation.raw_token
    new_token = invitation.renew!

    assert_nil ClientInvitation.find_by_token(old_token)
    assert_equal invitation, ClientInvitation.find_by_token(new_token)
    assert invitation.pending?
  end

  test "reports expired status" do
    invitation = ClientInvitation.create!(
      coach: @coach,
      email: "expired@example.com",
      expires_at: 1.minute.ago
    )

    assert invitation.expired?
    assert_equal "expired", invitation.status
    assert_not invitation.pending?
  end

  test "requires a coach user" do
    invitation = ClientInvitation.new(coach: users(:client_alice), email: "invalid@example.com")

    assert_not invitation.valid?
    assert_includes invitation.errors[:coach], "must have the coach role"
  end
end
