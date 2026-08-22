require "test_helper"
require "openssl"

module Billing
  module RevenueCat
    class WebhookVerifierTest < ActiveSupport::TestCase
      SECRET = "whsec_test"
      BODY = '{"event":{"id":"evt_1","type":"INITIAL_PURCHASE"}}'

      def signed_header(body: BODY, secret: SECRET, timestamp: Time.now.to_i)
        signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
        "t=#{timestamp},v1=#{signature}"
      end

      test "accepts a correctly signed payload" do
        assert WebhookVerifier.valid?(
          raw_body: BODY,
          signature_header: signed_header,
          signing_secret: SECRET
        )
      end

      test "rejects a tampered body" do
        header = signed_header
        refute WebhookVerifier.valid?(
          raw_body: BODY + "tampered",
          signature_header: header,
          signing_secret: SECRET
        )
      end

      test "rejects the wrong secret" do
        header = signed_header(secret: "wrong-secret")
        refute WebhookVerifier.valid?(raw_body: BODY, signature_header: header, signing_secret: SECRET)
      end

      test "rejects a stale timestamp" do
        header = signed_header(timestamp: 10.minutes.ago.to_i)
        refute WebhookVerifier.valid?(raw_body: BODY, signature_header: header, signing_secret: SECRET)
      end

      test "rejects a missing header" do
        refute WebhookVerifier.valid?(raw_body: BODY, signature_header: nil, signing_secret: SECRET)
      end

      test "rejects a malformed header without raising" do
        refute WebhookVerifier.valid?(raw_body: BODY, signature_header: "garbage", signing_secret: SECRET)
        refute WebhookVerifier.valid?(raw_body: BODY, signature_header: "t=abc,v1=xyz", signing_secret: SECRET)
      end

      test "falls back to the static shared secret when no signing secret is configured" do
        assert WebhookVerifier.valid?(
          raw_body: BODY,
          authorization_header: "shared-secret",
          signing_secret: nil,
          shared_secret: "shared-secret"
        )
        refute WebhookVerifier.valid?(
          raw_body: BODY,
          authorization_header: "wrong",
          signing_secret: nil,
          shared_secret: "shared-secret"
        )
      end

      test "rejects everything when nothing is configured" do
        refute WebhookVerifier.valid?(raw_body: BODY, signature_header: signed_header, signing_secret: nil, shared_secret: nil)
      end
    end
  end
end
