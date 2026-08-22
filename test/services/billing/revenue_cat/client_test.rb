require "test_helper"

module Billing
  module RevenueCat
    class ClientTest < ActiveSupport::TestCase
      # Mirrors Catalog::Translation::GoogleAdapterTest's FakeHttp shape —
      # Data rather than Struct, since Array() on a Struct would splat a
      # single response into [code, body].
      FakeResponse = Data.define(:code, :body)

      class FakeHttp
        attr_reader :requests

        def initialize(responses)
          @responses = responses.is_a?(::Array) ? responses.dup : [ responses ]
          @requests = []
        end

        def request(uri, request)
          @requests << { uri: uri, headers: request.each_header.to_h }
          @responses.size > 1 ? @responses.shift : @responses.first
        end
      end

      def response(code, body)
        FakeResponse.new(code: code.to_s, body: body)
      end

      def ok(items)
        response(200, JSON.generate(items: items))
      end

      def build(responses, secret_key: "sk-test", project_id: "proj-test")
        Client.new(secret_key: secret_key, project_id: project_id, http: FakeHttp.new(responses))
      end

      test "parses entitlements from the items array" do
        client = build(ok([
          { "entitlement_id" => "studio_pro", "gives_access" => true, "expires_at" => "2026-09-01T00:00:00Z" }
        ]))

        result = client.entitlements("42")

        assert_equal [ { entitlement_id: "studio_pro", gives_access: true, expires_at: "2026-09-01T00:00:00Z" } ], result
      end

      test "sends the secret key as a bearer token, never in the URL" do
        http = FakeHttp.new(ok([]))
        Client.new(secret_key: "super-secret", project_id: "proj", http: http).entitlements("42")

        request = http.requests.first
        assert_equal "Bearer super-secret", request[:headers]["authorization"]
        assert_not_includes request[:uri].to_s, "super-secret"
      end

      test "does not leak the key through inspect" do
        client = build(ok([]), secret_key: "super-secret")

        assert_not_includes client.inspect, "super-secret"
        assert_includes client.inspect, "configured=true"
      end

      test "is not configured without both a secret key and a project id" do
        assert_not Client.new(secret_key: nil, project_id: "proj").configured?
        assert_not Client.new(secret_key: "sk", project_id: nil).configured?
        assert_raises(Errors::NotConfigured) { Client.new(secret_key: nil, project_id: nil).entitlements("42") }
      end

      test "treats an unknown customer (404) as no purchases, not an error" do
        assert_equal [], build(response(404, "{}")).entitlements("42")
      end

      test "maps provider failures onto the shared error types" do
        assert_raises(Errors::Rejected) { build(response(401, "{}")).entitlements("42") }
        assert_raises(Errors::Rejected) { build(response(429, "{}")).entitlements("42") }
        assert_raises(Errors::Transient) { build(response(503, "{}")).entitlements("42") }
        assert_raises(Errors::Schema) { build(response(418, "{}")).entitlements("42") }
      end

      test "unparseable json is a schema error and does not echo the body" do
        error = assert_raises(Errors::Schema) { build(response(200, "not json")).entitlements("42") }

        assert_not_includes error.message, "not json"
      end

      test "a missing items key is a schema error" do
        assert_raises(Errors::Schema) { build(response(200, "{}")).entitlements("42") }
      end
    end
  end
end
