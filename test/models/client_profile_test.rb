require "test_helper"

class ClientProfileTest < ActiveSupport::TestCase
  setup do
    @coach = users(:coach_john)
  end

  def build(**attributes)
    ClientProfile.new({ coach: @coach, name: "Dana" }.merge(attributes))
  end

  test "fixtures are valid" do
    assert client_profiles(:carla_prepared).valid?
    assert client_profiles(:alice_profile).valid?
  end

  test "only a name is required" do
    assert build.valid?
    assert_not build(name: "").valid?
    assert_not build(name: "   ").valid?
  end

  test "name is limited to 100 characters" do
    assert_not build(name: "a" * 101).valid?
  end

  test "blank optional fields are stored as null" do
    profile = build(email: "  ", phone: "", level: "", goal: " ", limitations: "", notes: "  ")
    profile.save!
    assert_equal [ nil ], profile.attributes.values_at("email", "phone", "level", "goal", "limitations", "notes").uniq
  end

  test "email is normalized and must look like an email" do
    profile = build(email: "  Dana@Example.COM ")
    profile.save!
    assert_equal "dana@example.com", profile.email
    assert_not build(email: "not-an-email").valid?
  end

  test "email is unique per coach, ignoring case" do
    build(email: "dana@example.com").save!
    duplicate = build(name: "Other", email: "DANA@example.com")
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test "several profiles may have no email" do
    build.save!
    assert build(name: "Eve").valid?
  end

  test "another coach may use the same email" do
    other_coach = User.create!(name: "Other Coach", email: "other-coach-profile@example.com", role: :coach)
    build(email: "dana@example.com").save!
    assert ClientProfile.new(coach: other_coach, name: "Dana", email: "dana@example.com").valid?
  end

  test "level and goal must be known values" do
    assert build(level: "advanced", goal: "fat_loss").valid?
    assert_not build(level: "expert").valid?
    assert_not build(goal: "world_domination").valid?
  end

  test "long text fields are limited" do
    assert build(limitations: "a" * 2000, notes: "b" * 2000).valid?
    assert_not build(limitations: "a" * 2001).valid?
    assert_not build(notes: "b" * 2001).valid?
    assert_not build(phone: "1" * 41).valid?
  end

  test "the owner must be a coach" do
    assert_not ClientProfile.new(coach: users(:client_alice), name: "Dana").valid?
  end

  test "linked? follows the user" do
    assert client_profiles(:alice_profile).linked?
    assert_not client_profiles(:carla_prepared).linked?
  end

  test "a user has one profile" do
    duplicate = ClientProfile.new(coach: @coach, name: "Again", user: users(:client_alice))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "deleting a client's account deletes the profile the coach kept of them" do
    profile_id = client_profiles(:alice_profile).id
    assert_difference "ClientProfile.count", -1 do
      users(:client_alice).destroy!
    end
    assert_not ClientProfile.exists?(profile_id)
  end

  test "deleting the coach deletes their profiles" do
    assert_difference "ClientProfile.count", -3 do
      @coach.destroy!
    end
  end
end
