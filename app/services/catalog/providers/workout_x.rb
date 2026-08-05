module Catalog
  module Providers
    # Adapter for the WorkoutX exercise API.
    #
    # The only class that knows this provider's URLs, header names, envelope
    # shape, and error semantics. It hands Catalog::Sync raw record hashes;
    # Catalog::NormalizeExercise turns those into Lactic's vocabulary.
    #
    # The API key is read from the environment and travels as a header. It is
    # never placed in a URL, never logged, and never included in an exception
    # message — `#inspect` is overridden so it cannot leak through a backtrace
    # or an error reporter either.
    class WorkoutX
      BASE_URL = "https://api.workoutxapp.com/v1".freeze
      SOURCE = "workoutx".freeze

      # The free plan silently caps a page at 10 records regardless of what is
      # requested, so pagination must advance by what actually came back.
      DEFAULT_PAGE_SIZE = 100

      MAX_ATTEMPTS = 3
      BASE_BACKOFF = 0.5

      ACCEPTED_MIME = "image/gif".freeze
      # Observed media runs to ~700KB. This is a guard against a runaway or
      # hostile response, not a expectation of the real size.
      ANIMATION_MAX_BYTES = 8_000_000

      # A catalog of ~1,300 records at 100 per page is ~14 requests. This only
      # exists so a provider bug cannot spin forever.
      MAX_PAGES = 500

      Page = Data.define(:records, :total, :count)

      def initialize(api_key: ENV["WORKOUTX_API_KEY"], transport: HttpTransport.new, sleeper: nil)
        @api_key = api_key.to_s.strip
        @transport = transport
        @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      end

      def source = SOURCE

      def configured? = @api_key.present?

      # Never expose the key through inspection, which is what an exception
      # reporter or `p` would otherwise print.
      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      def fetch_page(limit: DEFAULT_PAGE_SIZE, offset: 0)
        body = get("/exercises", limit: limit, offset: offset)
        envelope = parse(body)

        records = envelope["data"]
        unless records.is_a?(Array)
          raise Errors::Schema, "expected a 'data' array, got #{envelope.keys.inspect}"
        end

        Page.new(records: records, total: envelope["total"], count: envelope["count"])
      end

      # Yields each raw record across the whole catalog.
      #
      # Advances by the number of records actually returned rather than by the
      # requested limit. Advancing by the limit would silently skip 90 of every
      # 100 records on a plan that caps pages at 10.
      def each_record(page_size: DEFAULT_PAGE_SIZE)
        return enum_for(:each_record, page_size: page_size) unless block_given?

        offset = 0
        pages = 0

        loop do
          page = fetch_page(limit: page_size, offset: offset)
          break if page.records.empty?

          page.records.each { |record| yield record }

          offset += page.records.size
          pages += 1
          break if pages >= MAX_PAGES
          break if page.total.is_a?(Integer) && offset >= page.total
        end
      end

      # Reports the catalog size without walking it, so a sync can tell whether
      # it saw everything before deactivating anything.
      def total_count
        fetch_page(limit: 1, offset: 0).total
      end

      Animation = Data.define(:bytes, :mime_type) do
        def byte_size = bytes.bytesize
      end

      # Fetches one animation's bytes with the provider key attached
      # server-side.
      #
      # The provider serves media from the API host and returns 401 without the
      # key, so a client cannot fetch it directly — that is the whole reason
      # the Lactic proxy exists.
      #
      # Not retried. A coach is waiting on this render, and a retry storm would
      # multiply an already expensive request: every fetch, including a repeat
      # of the same image, costs one request from the monthly quota.
      def fetch_animation(provider_url, max_bytes: ANIMATION_MAX_BYTES)
        raise Errors::Authentication, "WORKOUTX_API_KEY is not set" unless configured?
        raise Errors::Schema, "media url is blank" if provider_url.blank?
        unless provider_url.to_s.start_with?("#{BASE_URL}/")
          # Refuse to attach the credential to anything but the provider's own
          # media path. Without this a poisoned provider_url in the database
          # would send the API key to an arbitrary host.
          raise Errors::Schema, "media url is not a provider url"
        end

        response = @transport.get_binary(
          provider_url,
          headers: { "X-WorkoutX-Key" => @api_key, "Accept" => ACCEPTED_MIME },
          max_bytes: max_bytes
        )

        interpret(response) # maps 401/403/429/5xx to the shared error types

        mime = response.headers["content-type"].to_s.split(";").first.to_s.strip.downcase
        raise Errors::Schema, "unexpected content type #{mime.inspect}" unless mime == ACCEPTED_MIME
        raise Errors::Schema, "empty media response" if response.body.empty?

        Animation.new(bytes: response.body, mime_type: mime)
      end

      private

      def get(path, params = {})
        raise Errors::Authentication, "WORKOUTX_API_KEY is not set" unless configured?

        uri = URI("#{BASE_URL}#{path}")
        uri.query = URI.encode_www_form(params) if params.any?

        with_retries do
          response = @transport.get(uri.to_s, headers: { "X-WorkoutX-Key" => @api_key, "Accept" => "application/json" })
          interpret(response)
        end
      end

      def interpret(response)
        case response.status
        when 200 then response.body
        when 401, 403
          raise Errors::Authentication, "provider rejected the credentials (HTTP #{response.status})"
        when 429
          raise Errors::Quota, "provider quota or rate limit exceeded (HTTP 429)"
        when 400..499
          raise Errors::Schema, "unexpected client error (HTTP #{response.status})"
        else
          raise Errors::Transient, "provider error (HTTP #{response.status})"
        end
      end

      def parse(body)
        # The transport hands back raw bytes so it can carry binary media
        # unharmed. JSON is text, and the catalog contains characters such as
        # the degree sign, so the encoding is applied here rather than there.
        parsed = JSON.parse(body.to_s.dup.force_encoding("UTF-8"))
        raise Errors::Schema, "expected a JSON object, got #{parsed.class}" unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError
        # The body is withheld on purpose: it is unvalidated third-party
        # content and this message is persisted to catalog_sync_runs.
        raise Errors::Schema, "provider returned unparseable JSON"
      end

      # Retries only what retrying can fix. Authentication and schema failures
      # fail immediately, because a second identical request returns the same
      # answer and each attempt costs a request from the monthly quota.
      def with_retries
        attempt = 0

        begin
          attempt += 1
          yield
        rescue Errors::Transient, Errors::Quota => e
          raise if attempt >= MAX_ATTEMPTS

          @sleeper.call(BASE_BACKOFF * (2**(attempt - 1)))
          retry
        end
      end
    end
  end
end
