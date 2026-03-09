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

  test "coaches scope" do
    assert_includes User.coaches, users(:coach_john)
    assert_not_includes User.coaches, users(:client_alice)
  end

  test "clients scope" do
    assert_includes User.clients, users(:client_alice)
    assert_not_includes User.clients, users(:coach_john)
  end
end
