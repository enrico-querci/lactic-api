require "net/http"
require "json"

module Catalog
  module Translation
    # Google Cloud Translation (v2 REST) behind the adapter contract.
    #
    # The contract another provider must satisfy is small on purpose:
    #
    #   #configured?                     -> true when it can be used
    #   #translate(texts, to:, from:)    -> Array<String>, same order and length
    #
    # v2 REST with an API key rather than the google-cloud-translate gem: it is
    # a single POST, and adding a gem plus service-account credentials commits
    # the project to a dependency before the pricing and terms check the plan
    # requires has happened.
    #
    # NOTE: this has been exercised against a fake transport, not against the
    # live Google service. No credential exists yet, and configuring one is
    # explicitly gated on that pricing and terms check.
    class GoogleAdapter
      ENDPOINT = "https://translation.googleapis.com/language/translate/v2".freeze

      # Google documents a limit on segments and total characters per request.
      # Kept well under both, since one oversized request fails the whole batch
      # while one extra request costs only latency.
      MAX_SEGMENTS = 100
      MAX_CHARACTERS = 20_000

      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 20

      def initialize(api_key: ENV["GOOGLE_TRANSLATE_API_KEY"], http: nil)
        @api_key = api_key.to_s.strip
        @http = http
      end

      def configured? = @api_key.present?

      def name = "google"

      # Never expose the key through inspection.
      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      # Returns translations positionally aligned with `texts`. Callers rely on
      # that alignment to put instruction steps back in order.
      def translate(texts, to:, from: "en")
        raise Errors::NotConfigured, "GOOGLE_TRANSLATE_API_KEY is not set" unless configured?

        segments = Array(texts).map(&:to_s)
        return [] if segments.empty?

        batches(segments).flat_map { |batch| request_translation(batch, to: to, from: from) }
      end

      private

      # Splits on both limits at once: too many segments and too many
      # characters each fail the whole request, and an extra request costs only
      # latency. A single segment over the character limit becomes its own
      # batch rather than being dropped — instructions are a sentence or two,
      # so that is a theoretical case.
      def batches(segments)
        result = []
        current = []
        characters = 0

        segments.each do |segment|
          too_many = current.size >= MAX_SEGMENTS
          too_long = characters + segment.length > MAX_CHARACTERS
          if current.any? && (too_many || too_long)
            result << current
            current = []
            characters = 0
          end

          current << segment
          characters += segment.length
        end

        result << current if current.any?
        result
      end

      def request_translation(batch, to:, from:)
        uri = URI(ENDPOINT)
        # The key goes in the query string because that is the only place this
        # API accepts it. It is never logged and never returned to a client.
        uri.query = URI.encode_www_form(key: @api_key)

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(q: batch, target: to, source: from, format: "text")

        response = transport.request(uri, request)
        interpret(response, expected: batch.size)
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, EOFError, SocketError => e
        raise Errors::Transient, "network failure: #{e.class}"
      end

      def interpret(response, expected:)
        case response.code.to_i
        when 200 then parse(response.body, expected: expected)
        when 400, 401, 403 then raise Errors::Rejected, "translation provider rejected the request (HTTP #{response.code})"
        when 429 then raise Errors::Rejected, "translation provider quota exceeded (HTTP 429)"
        when 500..599 then raise Errors::Transient, "translation provider error (HTTP #{response.code})"
        else raise Errors::Schema, "unexpected status #{response.code}"
        end
      end

      def parse(body, expected:)
        payload = JSON.parse(body.to_s)
        translations = payload.dig("data", "translations")
        raise Errors::Schema, "missing data.translations" unless translations.is_a?(Array)

        results = translations.map { |t| t["translatedText"].to_s }
        # Misalignment would silently put the wrong Italian on the wrong
        # instruction step, which is worse than failing.
        unless results.size == expected
          raise Errors::Schema, "expected #{expected} translations, got #{results.size}"
        end

        results
      rescue JSON::ParserError
        raise Errors::Schema, "translation provider returned unparseable JSON"
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
