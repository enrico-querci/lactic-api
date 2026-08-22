require "test_helper"

class Api::V1::Coach::SubscriptionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
  end

  test "show returns the free plan for a coach with no subscription" do
    get api_v1_coach_subscription_path, headers: auth_headers_for(@coach)

    assert_response :success
    body = response.parsed_body
    assert_equal "free", body["plan"]
    assert_equal Billing::Plans::FREE_CLIENT_LIMIT, body["client_limit"]
  end

  test "show reflects an active paid subscription" do
    CoachSubscription.create!(user: @coach, plan_key: "pro", expires_at: 1.day.from_now)

    get api_v1_coach_subscription_path, headers: auth_headers_for(@coach)

    body = response.parsed_body
    assert_equal "pro", body["plan"]
    assert_equal 15, body["client_limit"]
  end

  test "show is 401 without auth" do
    get api_v1_coach_subscription_path

    assert_response :unauthorized
  end

  test "show is 403 for a client" do
    get api_v1_coach_subscription_path, headers: auth_headers_for(users(:client_alice))

    assert_response :forbidden
  end

  test "sync fetches from RevenueCat and persists the result" do
    original = Billing::RevenueCat::Client.instance_method(:entitlements)
    Billing::RevenueCat::Client.define_method(:entitlements) do |_app_user_id|
      [ { entitlement_id: "studio_pro_plus", gives_access: true, expires_at: "2026-09-01T00:00:00Z" } ]
    end

    post sync_api_v1_coach_subscription_path, headers: auth_headers_for(@coach)

    assert_response :success
    assert_equal "pro_plus", response.parsed_body["plan"]
    assert_equal "pro_plus", @coach.reload.coach_subscription.plan_key
  ensure
    Billing::RevenueCat::Client.define_method(:entitlements, original)
  end

  test "sync returns 503 when billing is not configured" do
    original_key = ENV.delete("REVENUECAT_SECRET_API_KEY")
    original_project = ENV.delete("REVENUECAT_PROJECT_ID")

    post sync_api_v1_coach_subscription_path, headers: auth_headers_for(@coach)

    assert_response :service_unavailable
  ensure
    ENV["REVENUECAT_SECRET_API_KEY"] = original_key if original_key
    ENV["REVENUECAT_PROJECT_ID"] = original_project if original_project
  end
end
