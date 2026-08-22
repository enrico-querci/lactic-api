require "net/http"
require "json"

module Billing
  module RevenueCat
    # RevenueCat REST API v2 client, behind the same seam-injection shape as
    # Catalog::Translation::GoogleAdapter: no HTTP gem, a DefaultTransport
    # that tests replace.
    #
    # NOTE: the exact response shape of GET .../entitlements was not
    # confirmed against a live sandbox project at the time this was written
    # (docs describe the fields but not a worked example of this specific
    # endpoint). #entitlements raises Errors::Schema on anything that
    # doesn't match the shape assumed below rather than silently
    # misreading it — if that fires against the real API, fix the parsing
    # here, not the caller.
    class Client
      BASE_URL = "https://api.revenuecat.com/v2".freeze

      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 15

      def initialize(secret_key: ENV["REVENUECAT_SECRET_API_KEY"],
                      project_id: ENV["REVENUECAT_PROJECT_ID"],
                      http: nil)
        @secret_key = secret_key.to_s.strip
        @project_id = project_id.to_s.strip
        @http = http
      end

      def configured? = @secret_key.present? && @project_id.present?

      # Never expose the key through inspection.
      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      # Returns an Array of { entitlement_id:, gives_access:, expires_at: }.
      # Callers pick the most generous plan among the ones with
      # gives_access == true — RevenueCat, not this client, is the
      # authority on whether a grace period or billing issue still grants
      # access.
      def entitlements(app_user_id)
        raise Errors::NotConfigured, "REVENUECAT_SECRET_API_KEY/REVENUECAT_PROJECT_ID not set" unless configured?

        uri = URI("#{BASE_URL}/projects/#{@project_id}/customers/#{app_user_id}/entitlements")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@secret_key}"
        request["Accept"] = "application/json"

        response = transport.request(uri, request)
        interpret(response)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, EOFError, SocketError => e
        raise Errors::Transient, "network failure: #{e.class}"
      end

      private

      def interpret(response)
        case response.code.to_i
        when 200 then parse(response.body)
        when 404 then [] # unknown customer: no purchases yet, not an error
        when 401, 403 then raise Errors::Rejected, "RevenueCat rejected the request (HTTP #{response.code})"
        when 429 then raise Errors::Rejected, "RevenueCat rate limit exceeded (HTTP 429)"
        when 500..599 then raise Errors::Transient, "RevenueCat error (HTTP #{response.code})"
        else raise Errors::Schema, "unexpected status #{response.code}"
        end
      end

      def parse(body)
        payload = JSON.parse(body.to_s)
        items = payload["items"]
        raise Errors::Schema, "missing items array" unless items.is_a?(Array)

        items.map do |item|
          {
            entitlement_id: item["entitlement_id"] || item["lookup_key"],
            gives_access: item["gives_access"],
            expires_at: item["expires_at"]
          }
        end
      rescue JSON::ParserError
        raise Errors::Schema, "RevenueCat returned unparseable JSON"
      end

      def transport
        @transport ||= @http || DefaultTransport.new
      end

      # Seam for tests. The real one is four lines.
      class DefaultTransport
        def request(uri, request)
          Net::HTTP.start(uri.host, uri.port, use_ssl: true,
            open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
            http.request(request)
          end
        end
      end
    end
  end
end
