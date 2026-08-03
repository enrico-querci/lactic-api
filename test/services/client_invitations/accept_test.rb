require "test_helper"

class ClientInvitations::AcceptTest < ActiveSupport::TestCase
  setup do
    @coach = users(:coach_john)
    @client = User.create!(name: "Invited Client", email: "invited@example.com", role: :client)
    @invitation = ClientInvitation.create!(coach: @coach, email: @client.email)
  end

  test "links the client and marks the invitation accepted" do
    ClientInvitations::Accept.call(invitation: @invitation, user: @client)

    assert_equal @coach, @client.reload.coach
    assert @invitation.reload.accepted_at.present?
    assert_equal "accepted", @invitation.status
  end

  test "rejects a different signed-in email" do
    other_client = User.create!(name: "Other", email: "other-invite@example.com", role: :client)

    error = assert_raises(ClientInvitations::Accept::AcceptanceError) do
      ClientInvitations::Accept.call(invitation: @invitation, user: other_client)
    end

    assert_match @invitation.email, error.message
    assert_nil other_client.reload.coach_id
  end

  test "rejects an account linked to another coach" do
    other_coach = User.create!(name: "Other Coach", email: "other-coach-invite@example.com", role: :coach)
    @client.update!(coach: other_coach)

    assert_raises(ClientInvitations::Accept::AcceptanceError) do
      ClientInvitations::Accept.call(invitation: @invitation, user: @client)
    end
  end
end
