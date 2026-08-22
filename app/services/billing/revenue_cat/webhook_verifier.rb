require "openssl"

module Billing
  module RevenueCat
    # Verifies an inbound RevenueCat webhook is genuine before its body is
    # parsed or acted on. Prefers the HMAC signature
    # (X-RevenueCat-Webhook-Signature: t=<unix>,v1=<hex>, computed over
    # "<timestamp>.<raw body>") when a signing secret is configured; falls
    # back to the older static Authorization-header shared secret
    # otherwise. Returns false (never raises) on anything malformed, so a
    # bad request cleanly 401s rather than 500ing.
    #
    # NOTE: confirm the exact signature header name and where the signing
    # secret lives in the RevenueCat dashboard before relying on this in
    # production — community reports suggest this header has been renamed
    # recently and this file was written from docs, not a live payload.
    class WebhookVerifier
      MAX_SKEW_SECONDS = 300

      def self.valid?(raw_body:, signature_header: nil, authorization_header: nil,
                       signing_secret: ENV["REVENUECAT_WEBHOOK_SIGNING_SECRET"],
                       shared_secret: ENV["REVENUECAT_WEBHOOK_SHARED_SECRET"])
        if signing_secret.present?
          valid_signature?(raw_body, signature_header, signing_secret)
        elsif shared_secret.present?
          valid_shared_secret?(authorization_header, shared_secret)
        else
          false
        end
      end

      def self.valid_signature?(raw_body, header, secret)
        return false if header.blank?

        parts = parse_signature_header(header)
        timestamp = parts["t"]
        signature = parts["v1"]
        return false if timestamp.blank? || signature.blank?
        return false unless timestamp.match?(/\A\d+\z/)
        return false if (Time.now.to_i - timestamp.to_i).abs > MAX_SKEW_SECONDS

        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
        ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end
      private_class_method :valid_signature?

      def self.parse_signature_header(header)
        header.split(",").each_with_object({}) do |pair, acc|
          key, value = pair.split("=", 2)
          acc[key] = value if key && value
        end
      end
      private_class_method :parse_signature_header

      def self.valid_shared_secret?(header, secret)
        return false if header.blank?

        ActiveSupport::SecurityUtils.secure_compare(header, secret)
      end
      private_class_method :valid_shared_secret?
    end
  end
end
