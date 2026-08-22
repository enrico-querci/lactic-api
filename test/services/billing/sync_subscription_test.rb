require "test_helper"

module Billing
  class SyncSubscriptionTest < ActiveSupport::TestCase
    class FakeClient
      def initialize(entitlements) = @entitlements = entitlements
      def entitlements(_app_user_id) = @entitlements
    end

    def entitlement(id, gives_access: true, expires_at: "2026-09-01T00:00:00Z")
      { entitlement_id: id, gives_access: gives_access, expires_at: expires_at }
    end

    test "grants the plan for a single active entitlement" do
      coach = users(:coach_john)

      sub = SyncSubscription.call(app_user_id: coach.id.to_s, client: FakeClient.new([ entitlement("studio_pro") ]))

      assert_equal "pro", sub.plan_key
      assert_equal 15, sub.client_limit
      assert sub.active?
    end

    test "picks the most generous of several active entitlements" do
      coach = users(:coach_john)
      client = FakeClient.new([ entitlement("studio_pro"), entitlement("studio_unlimited", expires_at: nil) ])

      sub = SyncSubscription.call(app_user_id: coach.id.to_s, client: client)

      assert_equal "unlimited", sub.plan_key
      assert_nil sub.client_limit
    end

    test "ignores an entitlement that does not currently give access" do
      coach = users(:coach_john)
      client = FakeClient.new([ entitlement("studio_pro", gives_access: false) ])

      sub = SyncSubscription.call(app_user_id: coach.id.to_s, client: client)

      assert_equal "free", sub.plan_key
      assert_not sub.active?
    end

    test "ignores an unrecognized entitlement id" do
      coach = users(:coach_john)
      client = FakeClient.new([ entitlement("some_other_product") ])

      sub = SyncSubscription.call(app_user_id: coach.id.to_s, client: client)

      assert_equal "free", sub.plan_key
    end

    test "writes back to free when nothing is active" do
      coach = users(:coach_john)
      CoachSubscription.create!(user: coach, plan_key: "pro", expires_at: 1.day.from_now)

      sub = SyncSubscription.call(app_user_id: coach.id.to_s, client: FakeClient.new([]))

      assert_equal "free", sub.plan_key
      assert_not sub.active?
    end

    test "accepts an epoch-millisecond expiry" do
      coach = users(:coach_john)
      millis = 1.day.from_now.to_i * 1000
      client = FakeClient.new([ entitlement("studio_pro", expires_at: millis) ])

      sub = SyncSubscription.call(app_user_id: coach.id.to_s, client: client)

      assert_in_delta 1.day.from_now.to_i, sub.expires_at.to_i, 2
    end

    test "raises on an unparseable expiry rather than silently granting lifetime access" do
      coach = users(:coach_john)
      client = FakeClient.new([ entitlement("studio_pro", expires_at: "not-a-date") ])

      assert_raises(Errors::Schema) { SyncSubscription.call(app_user_id: coach.id.to_s, client: client) }
    end

    test "raises UnknownUser for an app_user_id with no matching user" do
      assert_raises(SyncSubscription::UnknownUser) do
        SyncSubscription.call(app_user_id: "999999", client: FakeClient.new([]))
      end
    end
  end
end
