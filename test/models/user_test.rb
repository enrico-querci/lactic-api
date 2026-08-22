require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid coach" do
    user = users(:coach_john)
    assert user.valid?
    assert user.coach?
  end

  test "valid client" do
    user = users(:client_alice)
    assert user.valid?
    assert user.client?
  end

  test "requires name" do
    user = User.new(email: "test@example.com", role: :client)
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "requires email" do
    user = User.new(name: "Test", role: :client)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires unique email" do
    user = User.new(name: "Dup", email: users(:coach_john).email, role: :client)
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "coach cannot have coach_id" do
    coach = User.new(name: "Bad Coach", email: "bad@example.com", role: :coach, coach: users(:coach_john))
    assert_not coach.valid?
    assert_includes coach.errors[:coach_id], "a coach cannot belong to another coach"
  end

  test "client can have coach" do
    client = users(:client_alice)
    assert_equal users(:coach_john), client.coach
  end

  test "coach has clients" do
    coach = users(:coach_john)
    assert_includes coach.clients, users(:client_alice)
    assert_includes coach.clients, users(:client_bob)
  end

  test "coach has client invitations" do
    invitation = ClientInvitation.create!(coach: users(:coach_john), email: "association@example.com")

    assert_includes users(:coach_john).client_invitations, invitation
  end

  test "coaches scope" do
    assert_includes User.coaches, users(:coach_john)
    assert_not_includes User.coaches, users(:client_alice)
  end

  test "clients scope" do
    assert_includes User.clients, users(:client_alice)
    assert_not_includes User.clients, users(:coach_john)
  end

  test "an unlimited comp-listed coach is never capped" do
    coach = User.create!(name: "Comped", email: "comped@example.com", role: :coach)
    CoachSubscription.create!(user: coach, plan_key: "pro", expires_at: 1.day.from_now)

    stub_coach_access(allowed: true) do
      assert_nil coach.client_limit
      assert coach.can_invite_client?
    end
  end

  test "a coach with no subscription is on the free plan" do
    coach = User.create!(name: "New Coach", email: "newcoach@example.com", role: :coach)

    assert_equal Billing::Plans::FREE_CLIENT_LIMIT, coach.client_limit
  end

  test "an expired subscription falls back to the free limit" do
    coach = User.create!(name: "Lapsed", email: "lapsed@example.com", role: :coach)
    CoachSubscription.create!(user: coach, plan_key: "unlimited", expires_at: 1.day.ago)

    assert_equal Billing::Plans::FREE_CLIENT_LIMIT, coach.client_limit
  end

  test "can_invite_client? at the exact boundary" do
    coach = User.create!(name: "Boundary", email: "boundary@example.com", role: :coach)
    2.times { |i| User.create!(name: "Client #{i}", email: "boundary-client-#{i}@example.com", role: :client, coach: coach) }
    assert coach.can_invite_client?, "2 of 3 free slots used should still allow inviting"

    User.create!(name: "Client 3", email: "boundary-client-3@example.com", role: :client, coach: coach)
    assert_not coach.can_invite_client?, "3 of 3 free slots used should block inviting"
  end

  test "a pending invitation counts against the limit" do
    coach = User.create!(name: "Pending", email: "pending@example.com", role: :coach)
    3.times { |i| ClientInvitation.create!(coach: coach, email: "pending-invite-#{i}@example.com") }

    assert_equal 3, coach.client_slots_used
    assert_not coach.can_invite_client?
  end

  test "an expired pending invitation does not count against the limit" do
    coach = User.create!(name: "ExpiredInvite", email: "expiredinvite@example.com", role: :coach)
    invitation = ClientInvitation.create!(coach: coach, email: "expired@example.com")
    invitation.update_column(:expires_at, 1.day.ago)

    assert_equal 0, coach.client_slots_used
    assert coach.can_invite_client?
  end

  private

  def stub_coach_access(allowed:)
    original = CoachAccess.method(:allowed?)
    CoachAccess.define_singleton_method(:allowed?) { |_email| allowed }
    yield
  ensure
    CoachAccess.define_singleton_method(:allowed?, original)
  end
end
