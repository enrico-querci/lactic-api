require "test_helper"

class CoachSubscriptionTest < ActiveSupport::TestCase
  test "active with no expiry (lifetime grant)" do
    sub = CoachSubscription.new(user: users(:coach_john), plan_key: "founding", expires_at: nil)
    assert sub.active?
    assert_nil sub.client_limit
  end

  test "active with a future expiry" do
    sub = CoachSubscription.new(user: users(:coach_john), plan_key: "pro", expires_at: 1.day.from_now)
    assert sub.active?
    assert_equal 15, sub.client_limit
  end

  test "inactive once expired" do
    sub = CoachSubscription.new(user: users(:coach_john), plan_key: "pro", expires_at: 1.day.ago)
    assert_not sub.active?
    assert_equal Billing::Plans::FREE_CLIENT_LIMIT, sub.client_limit
  end

  test "free plan is never active regardless of expires_at" do
    sub = CoachSubscription.new(user: users(:coach_john), plan_key: "free", expires_at: nil)
    assert_not sub.active?
  end

  test "rejects an unrecognized plan_key" do
    sub = CoachSubscription.new(user: users(:coach_john), plan_key: "bogus")
    assert_not sub.valid?
    assert_includes sub.errors[:plan_key], "is not included in the list"
  end

  test "one subscription per user" do
    CoachSubscription.create!(user: users(:coach_john), plan_key: "pro", expires_at: 1.day.from_now)
    dup = CoachSubscription.new(user: users(:coach_john), plan_key: "pro", expires_at: 1.day.from_now)

    assert_raises(ActiveRecord::RecordNotUnique) { dup.save! }
  end
end
