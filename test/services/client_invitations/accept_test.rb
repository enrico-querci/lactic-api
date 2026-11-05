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

  test "accepts a dotted Gmail invitation matched by its undotted account" do
    dotted_invitation = ClientInvitation.create!(coach: @coach, email: "mario.rossi@gmail.com")
    undotted_client = User.create!(name: "Mario Rossi", email: "mariorossi@gmail.com", role: :client)

    ClientInvitations::Accept.call(invitation: dotted_invitation, user: undotted_client)

    assert_equal @coach, undotted_client.reload.coach
  end

  test "accepts a plus-tagged Gmail invitation matched by its untagged account" do
    tagged_invitation = ClientInvitation.create!(coach: @coach, email: "mario+lactic@gmail.com")
    untagged_client = User.create!(name: "Mario", email: "mario@gmail.com", role: :client)

    ClientInvitations::Accept.call(invitation: tagged_invitation, user: untagged_client)

    assert_equal @coach, untagged_client.reload.coach
  end

  test "rejects dot variants on a non-Gmail domain" do
    dotted_invitation = ClientInvitation.create!(coach: @coach, email: "mario.rossi@studiofitness.it")
    undotted_client = User.create!(name: "Mario Rossi", email: "mariorossi@studiofitness.it", role: :client)

    assert_raises(ClientInvitations::Accept::AcceptanceError) do
      ClientInvitations::Accept.call(invitation: dotted_invitation, user: undotted_client)
    end
  end

  # Apple's relay address can never match, and signing in again gives the
  # same one, so the generic "sign in with <address>" would loop.
  test "explains Hide My Email instead of asking for an address the client cannot produce" do
    relay_client = User.create!(name: "Relay", email: "x7k2@privaterelay.appleid.com", role: :client)

    error = assert_raises(ClientInvitations::Accept::AcceptanceError) do
      ClientInvitations::Accept.call(invitation: @invitation, user: relay_client)
    end

    assert_match "Hide My Email", error.message
    assert_match @invitation.email, error.message
    assert_nil relay_client.reload.coach_id
    assert_nil @invitation.reload.accepted_at
  end

  test "links the prepared profile with the invited email to the new client" do
    profile = @coach.client_profiles.create!(name: "Prepared Name", email: @client.email, notes: "kept")

    assert_no_difference "ClientProfile.count" do
      ClientInvitations::Accept.call(invitation: @invitation, user: @client)
    end

    profile.reload
    assert_equal @client, profile.user
    assert_equal [ "Prepared Name", "kept" ], [ profile.name, profile.notes ]
  end

  test "creates a profile when the coach had none for that email" do
    assert_difference "ClientProfile.count", 1 do
      ClientInvitations::Accept.call(invitation: @invitation, user: @client)
    end

    profile = @client.reload.client_profile
    assert_equal [ @coach, "Invited Client", "invited@example.com" ], [ profile.coach, profile.name, profile.email ]
  end

  test "does not take over a profile that already belongs to another account" do
    other = User.create!(name: "Someone", email: "someone@example.com", role: :client, coach: @coach)
    taken = @coach.client_profiles.create!(name: "Taken", email: @client.email, user: other)

    ClientInvitations::Accept.call(invitation: @invitation, user: @client)

    assert_equal other, taken.reload.user
    assert_equal "Invited Client", @client.reload.client_profile.name
  end

  test "the client still joins when the profile cannot be linked" do
    # This account already has a profile with another coach, so a second one
    # would break the one-profile-per-user rule: the link fails, the join must not.
    other_coach = User.create!(name: "Other Coach", email: "other-coach-link@example.com", role: :coach)
    other_coach.client_profiles.create!(name: "Elsewhere", user: @client)

    assert_no_difference "ClientProfile.count" do
      ClientInvitations::Accept.call(invitation: @invitation, user: @client)
    end

    assert_equal @coach, @client.reload.coach
    assert_equal "accepted", @invitation.reload.status
  end
end
