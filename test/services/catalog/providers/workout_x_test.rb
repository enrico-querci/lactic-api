require "test_helper"

module Catalog
  module Providers
    class WorkoutXTest < ActiveSupport::TestCase
      # Stands in for the network. The adapter takes its transport as a
      # dependency precisely so tests can drive every failure mode — timeout,
      # 429, 5xx, malformed JSON — without a stubbing gem or a live request.
      class FakeTransport
        attr_reader :calls

        def initialize(responses)
          @responses = Array(responses)
          @calls = []
        end

        def get(url, headers: {})
          @calls << { url: url, headers: headers }
          nxt = @responses.size > 1 ? @responses.shift : @responses.first
          raise nxt if nxt.is_a?(Exception) || (nxt.is_a?(Class) && nxt <= Exception)

          nxt
        end
      end

      def ok(body)
        HttpTransport::Response.new(status: 200, body: body, headers: {})
      end

      def status(code, body = "{}")
        HttpTransport::Response.new(status: code, body: body, headers: {})
      end

      def page_body(records, total: nil)
        JSON.generate({ "total" => total || records.size, "count" => records.size, "data" => records })
      end

      def fixture_records
        @fixture_records ||= JSON.parse(
          file_fixture("workoutx/exercises_list_response.json").read
        ).fetch("data")
      end

      def build(responses, api_key: "test-key")
        WorkoutX.new(api_key: api_key, transport: FakeTransport.new(responses), sleeper: ->(_) { })
      end

      # --- Happy path ---------------------------------------------------------

      test "parses the real provider envelope" do
        provider = build(ok(file_fixture("workoutx/exercises_list_response.json").read))
        page = provider.fetch_page

        assert_equal 3, page.records.size
        assert_equal 1327, page.total
        assert_equal "0001", page.records.first["id"]
      end

      test "sends the key as a header, never in the url" do
        transport = FakeTransport.new(ok(page_body([])))
        WorkoutX.new(api_key: "secret-key", transport: transport, sleeper: ->(_) { }).fetch_page

        call = transport.calls.first
        assert_equal "secret-key", call[:headers]["X-WorkoutX-Key"]
        assert_not_includes call[:url], "secret-key"
        assert_not_includes call[:url], "api-key"
      end

      test "does not leak the key through inspect" do
        provider = build(ok(page_body([])), api_key: "secret-key")

        assert_not_includes provider.inspect, "secret-key"
        assert_includes provider.inspect, "configured=true"
      end

      test "reports the catalog total without walking it" do
        transport = FakeTransport.new(ok(page_body(fixture_records, total: 1327)))
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_equal 1327, provider.total_count
        assert_equal 1, transport.calls.size
      end

      # --- Pagination ---------------------------------------------------------

      test "advances by records returned, not by the requested limit" do
        # The free plan caps a page at 10 no matter what is asked for.
        # Advancing by the limit would skip 90 of every 100 records.
        first = Array.new(10) { |i| { "id" => format("%04d", i + 1) } }
        second = Array.new(10) { |i| { "id" => format("%04d", i + 11) } }
        transport = FakeTransport.new([
          ok(page_body(first, total: 20)),
          ok(page_body(second, total: 20)),
          ok(page_body([], total: 20))
        ])
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        ids = provider.each_record(page_size: 100).map { |r| r["id"] }

        assert_equal 20, ids.size
        assert_equal "0020", ids.last
        assert_includes transport.calls[1][:url], "offset=10"
      end

      test "stops when the total has been reached" do
        records = Array.new(3) { |i| { "id" => i.to_s } }
        transport = FakeTransport.new(ok(page_body(records, total: 3)))
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_equal 3, provider.each_record.to_a.size
        assert_equal 1, transport.calls.size
      end

      test "stops on an empty page when no total is given" do
        transport = FakeTransport.new([
          ok(page_body([ { "id" => "1" } ], total: nil)),
          ok(JSON.generate({ "data" => [] }))
        ])
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_equal 1, provider.each_record.to_a.size
      end

      # --- Error mapping ------------------------------------------------------

      test "401 and 403 raise an authentication error" do
        [ 401, 403 ].each do |code|
          assert_raises(Errors::Authentication) { build(status(code)).fetch_page }
        end
      end

      test "429 raises a quota error" do
        assert_raises(Errors::Quota) { build(status(429)).fetch_page }
      end

      test "5xx raises a transient error" do
        assert_raises(Errors::Transient) { build(status(503)).fetch_page }
      end

      test "an unexpected 4xx raises a schema error" do
        assert_raises(Errors::Schema) { build(status(418)).fetch_page }
      end

      test "unparseable JSON raises a schema error without echoing the body" do
        error = assert_raises(Errors::Schema) { build(ok("<html>gateway</html>")).fetch_page }

        assert_not_includes error.message, "gateway"
      end

      test "a missing data array raises a schema error" do
        assert_raises(Errors::Schema) { build(ok(JSON.generate({ "total" => 1 }))).fetch_page }
      end

      test "a missing api key fails before any request is made" do
        transport = FakeTransport.new(ok(page_body([])))
        provider = WorkoutX.new(api_key: nil, transport: transport, sleeper: ->(_) { })

        assert_raises(Errors::Authentication) { provider.fetch_page }
        assert_empty transport.calls
        assert_not provider.configured?
      end

      # --- Retry --------------------------------------------------------------

      test "retries a transient failure and succeeds" do
        transport = FakeTransport.new([ status(503), status(503), ok(page_body([ { "id" => "1" } ])) ])
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_equal 1, provider.fetch_page.records.size
        assert_equal 3, transport.calls.size
      end

      test "gives up after the attempt limit" do
        transport = FakeTransport.new(status(503))
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_raises(Errors::Transient) { provider.fetch_page }
        assert_equal WorkoutX::MAX_ATTEMPTS, transport.calls.size
      end

      test "backs off exponentially between attempts" do
        delays = []
        transport = FakeTransport.new(status(503))
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(s) { delays << s })

        assert_raises(Errors::Transient) { provider.fetch_page }
        assert_equal [ 0.5, 1.0 ], delays
      end

      test "does not retry an authentication failure, since a retry costs quota and cannot help" do
        transport = FakeTransport.new(status(401))
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_raises(Errors::Authentication) { provider.fetch_page }
        assert_equal 1, transport.calls.size
      end

      test "does not retry a schema failure" do
        transport = FakeTransport.new(ok("not json"))
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_raises(Errors::Schema) { provider.fetch_page }
        assert_equal 1, transport.calls.size
      end

      test "a transport level network failure is transient and retried" do
        transport = FakeTransport.new([
          Errors::Transient.new("network failure: Net::ReadTimeout"),
          ok(page_body([ { "id" => "1" } ]))
        ])
        provider = WorkoutX.new(api_key: "k", transport: transport, sleeper: ->(_) { })

        assert_equal 1, provider.fetch_page.records.size
        assert_equal 2, transport.calls.size
      end
    end
  end
end
