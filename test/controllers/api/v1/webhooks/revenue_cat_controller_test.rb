require "test_helper"
require "openssl"

class Api::V1::Webhooks::RevenueCatControllerTest < ActionDispatch::IntegrationTest
  SECRET = "whsec_test"

  setup do
    @coach = users(:coach_john)
    ENV["REVENUECAT_WEBHOOK_SIGNING_SECRET"] = SECRET
  end

  teardown do
    ENV.delete("REVENUECAT_WEBHOOK_SIGNING_SECRET")
  end

  def signed_headers(body)
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", SECRET, "#{timestamp}.#{body}")
    { "Content-Type" => "application/json", "X-RevenueCat-Webhook-Signature" => "t=#{timestamp},v1=#{signature}" }
  end

  def event_body(id:, type: "INITIAL_PURCHASE", app_user_id: nil, environment: "PRODUCTION")
    JSON.generate(event: {
      id: id, type: type, app_user_id: app_user_id || @coach.id.to_s, environment: environment
    })
  end

  # This posts a raw JSON body rather than form-encoded params — every
  # other test in this suite uses params:, but a real HMAC needs the exact
  # bytes RevenueCat would sign, which only a raw string body preserves.
  def post_webhook(body, headers: nil)
    post api_v1_webhooks_revenuecat_path, params: body, headers: headers || signed_headers(body)
  end

  def stub_client(entitlements)
    original = Billing::RevenueCat::Client.instance_method(:entitlements)
    Billing::RevenueCat::Client.define_method(:entitlements) { |_app_user_id| entitlements }
    yield
  ensure
    Billing::RevenueCat::Client.define_method(:entitlements, original)
  end

  # Matches the save/redefine/restore idiom this suite already uses
  # elsewhere (CoachAccess, Auth::GoogleVerifier) rather than a mocking
  # library — Rails.env returns the same object across calls in-process,
  # so a singleton method on it is a safe, scoped stub.
  def stub_production!
    original = Rails.env.method(:production?)
    Rails.env.define_singleton_method(:production?) { true }
    yield
  ensure
    Rails.env.define_singleton_method(:production?, original)
  end

  test "rejects a request with no signature" do
    post api_v1_webhooks_revenuecat_path, params: event_body(id: "evt_1"), headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  test "rejects a tampered body" do
    body = event_body(id: "evt_1")
    headers = signed_headers(body)

    post api_v1_webhooks_revenuecat_path, params: body + "x", headers: headers

    assert_response :unauthorized
  end

  test "rejects malformed json even with a valid signature" do
    post_webhook("not json")

    assert_response :bad_request
  end

  test "accepts a valid event and syncs the subscription" do
    stub_client([ { entitlement_id: "studio_pro", gives_access: true, expires_at: "2026-09-01T00:00:00Z" } ]) do
      post_webhook(event_body(id: "evt_1"))
    end

    assert_response :success
    assert_equal "pro", @coach.reload.coach_subscription.plan_key
  end

  test "the same event_id delivered twice only applies once" do
    body = event_body(id: "evt_dup")

    stub_client([ { entitlement_id: "studio_pro", gives_access: true, expires_at: "2026-09-01T00:00:00Z" } ]) do
      post api_v1_webhooks_revenuecat_path, params: body, headers: signed_headers(body)
      assert_response :success
    end

    stub_client([]) do # if replay re-applied, this would flip the coach back to free
      post api_v1_webhooks_revenuecat_path, params: body, headers: signed_headers(body)
      assert_response :success
    end

    assert_equal "pro", @coach.reload.coach_subscription.plan_key
    assert_equal 1, RevenueCatWebhookEvent.where(event_id: "evt_dup").count
  end

  test "a sandbox event in production is recorded but not applied" do
    stub_production! do
      stub_client([ { entitlement_id: "studio_pro", gives_access: true, expires_at: "2026-09-01T00:00:00Z" } ]) do
        post_webhook(event_body(id: "evt_sandbox", environment: "SANDBOX"))
      end
    end

    assert_response :success
    assert_nil @coach.reload.coach_subscription
    record = RevenueCatWebhookEvent.find_by(event_id: "evt_sandbox")
    assert record.processed?
  end

  test "an unknown app_user_id is recorded without a 500" do
    stub_client([ { entitlement_id: "studio_pro", gives_access: true, expires_at: "2026-09-01T00:00:00Z" } ]) do
      post_webhook(event_body(id: "evt_unknown", app_user_id: "999999"))
    end

    assert_response :success
    assert RevenueCatWebhookEvent.find_by(event_id: "evt_unknown").processed?
  end
end
