# Stage 0 provider verification probe for the exercise catalog rebuild.
# See docs/exercise_catalog_v1_plan.md section 5.
#
# This is a throwaway measurement harness, deliberately kept OUT of app/ so it
# does not pre-empt the Stage 2 provider boundary (Catalog::Providers::WorkoutX).
# It uses only the Ruby standard library: no gem may be added for Stage 0.
#
# Usage:
#   WORKOUTX_API_KEY=... bin/rails workoutx:probe
#   WORKOUTX_API_KEY=... bin/rails workoutx:probe SAMPLE=40 CHANGES=1
#
# The key is read from the environment only. It is never echoed, never written
# to a fixture, and never included in an error message.

require "net/http"
require "json"

module WorkoutxProbe
  BASE_URL = "https://api.workoutxapp.com/v1"
  KEY_PLACEHOLDER = "wx_invalid_probe_key"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  # How many GIFs to fetch. Kept small: each fetch may consume BOTH a monthly
  # request and a slot on the separate unique-GIF meter, and on the RapidAPI
  # channel it also consumes metered bandwidth.
  GIF_SAMPLE = 8

  METERING_HEADERS = %w[
    x-workoutx-plan
    x-ratelimit-limit x-ratelimit-remaining
    x-quota-limit x-quota-remaining x-quota-reset
    x-unique-gif-limit x-unique-gif-used x-unique-gif-remaining
  ].freeze

  EXPECTED_FIELDS = %w[
    id name bodyPart target equipment difficulty mechanic force
    caloriesPerMinute popularityRank gifUrl isUnilateral
    recommendedSets recommendedReps met category description
    instructions secondaryMuscles joint_focus intensity_level movement_tags
  ].freeze

  def self.fixture_dir
    Rails.root.join("test/fixtures/files/workoutx")
  end

  # Minimal probe client. Not a provider adapter — Stage 2 owns that.
  class Client
    def initialize(key)
      @key = key
      @samples = []
      @captured = {}
    end

    def report_plan_headers
      response = get("/exercises", limit: 1)
      section "Plan and metering headers"
      puts "  HTTP #{response.code}"
      METERING_HEADERS.each do |header|
        value = response[header]
        puts format("  %-26s %s", header, value.nil? ? "(absent)" : value)
      end
      puts
      puts "  Interpretation:"
      puts "  - x-unique-gif-* present means a GIF budget exists SEPARATE from the"
      puts "    monthly request quota. Record the limit; compare it to catalog size."
      puts "  - If x-unique-gif-limit < total exercises, decision #1 (a GIF for every"
      puts "    exercise) is NOT satisfiable on this plan."
    end

    def report_catalog_coverage(sample_size)
      body = json(get("/exercises", limit: sample_size, offset: 0))

      section "Catalog coverage"
      # Print the envelope BEFORE extracting. `extract` guesses at the payload
      # key, and a guess that misses would otherwise report 0% for every field
      # with no indication that the envelope, not the data, was the problem.
      if body.is_a?(Hash)
        puts "  Envelope keys: #{body.keys.inspect}"
        counts = body.select { |_, value| value.is_a?(Numeric) }
        puts "  Numeric envelope values (candidate totals): #{counts.inspect}" if counts.any?
      else
        puts "  Envelope: bare array"
      end

      @samples = extract(body)
      puts "  Extracted #{@samples.size} record(s)"
      if @samples.empty?
        puts "  !! Extraction found nothing. The payload key is not 'data' or 'exercises'."
        puts "     Update WorkoutxProbe::Client#extract to match the envelope above."
        return
      end

      %w[id name bodyPart target equipment difficulty mechanic force
         gifUrl category description instructions secondaryMuscles].each do |field|
        present = @samples.count { |exercise| filled?(exercise[field]) }
        puts format("  %-18s %3d/%-3d  %5.1f%%", field, present, @samples.size,
                    (present.to_f / @samples.size) * 100)
      end

      observed = @samples.flat_map(&:keys).uniq
      undocumented = observed - EXPECTED_FIELDS
      never_seen = EXPECTED_FIELDS - observed
      puts "  Undocumented fields observed:    #{undocumented.inspect}" if undocumented.any?
      puts "  Documented fields never present: #{never_seen.inspect}" if never_seen.any?

      timestamps = observed.grep(/updated|modified|changed/i)
      puts "  Change-tracking timestamps: #{timestamps.any? ? timestamps.inspect : 'NONE FOUND'}"
      puts "  -> Without one, source_updated_at cannot be populated from the provider." if timestamps.empty?
    end

    def report_gif_characteristics
      section "GIF characteristics"
      urls = @samples.filter_map { |exercise| exercise["gifUrl"] }.first(GIF_SAMPLE)
      if urls.empty?
        puts "  No gifUrl values in the sample."
        return
      end

      puts "  Host: #{URI(urls.first).host} (note whether this is the API host or a CDN)"

      results = urls.map { |url| inspect_gif(url) }
      succeeded = results.select { |result| result[:status] == "200" }
      puts "  Fetched #{results.size}; HTTP 200: #{succeeded.size}"
      puts "  Statuses:   #{results.group_by { |r| r[:status] }.transform_values(&:size).inspect}"
      puts "  MIME types: #{succeeded.group_by { |r| r[:mime] }.transform_values(&:size).inspect}"

      # Asked once, not per URL: whether the key is required cannot vary by GIF,
      # and each extra call burns quota for no additional information.
      puts "  Same URL without the provider key: HTTP #{anonymous_status(urls.first)}"
      puts "  -> A 200 here would mean gifUrl is publicly reachable, which changes"
      puts "     the Stage 4 proxy rationale. A 401/403 confirms the proxy is required."

      sizes = succeeded.filter_map { |result| result[:bytes] }.sort
      if sizes.any?
        puts format("  Bytes  median %d  p90 %d  max %d",
                    percentile(sizes, 50), percentile(sizes, 90), sizes.last)
      end
      puts "  Dimensions: #{succeeded.filter_map { |r| r[:dimensions] }.tally.inspect}"
      puts "  NOTE: free-plan GIFs are documented as 180px and watermarked, so free-plan"
      puts "        measurements do NOT characterise production quality."
    end

    def report_pagination_and_stable_ids
      section "Pagination and ID stability"
      first  = json(get("/exercises", limit: 5, offset: 0))
      second = json(get("/exercises", limit: 5, offset: 5))
      repeat = json(get("/exercises", limit: 5, offset: 0))

      first_ids = extract(first).map { |exercise| exercise["id"] }
      second_ids = extract(second).map { |exercise| exercise["id"] }
      repeat_ids = extract(repeat).map { |exercise| exercise["id"] }

      puts "  offset=0 ids: #{first_ids.inspect}"
      puts "  offset=5 ids: #{second_ids.inspect}"
      puts "  Pages disjoint:      #{(first_ids & second_ids).empty?}"
      puts "  offset=0 repeatable: #{first_ids == repeat_ids}"
      puts "  Envelope keys: #{first.is_a?(Hash) ? first.keys.inspect : '(bare array)'}"
      puts "  -> A bare array means no total count; catalog size needs another source."
    end

    def report_changes_endpoint
      section "Incremental sync endpoint (Ultra only)"
      response = get("/exercises/changes", since: 30.days.ago.strftime("%Y-%m-%d"))
      puts "  HTTP #{response.code}"
      if response.code == "403"
        puts "  403 = plan restriction, confirming /changes requires Ultra."
      else
        body = json(response)
        puts "  Envelope keys: #{body.is_a?(Hash) ? body.keys.inspect : '(bare array)'}"
        @captured["changes_sample.json"] = JSON.pretty_generate(body)
      end
    end

    def report_error_behaviour
      section "Error behaviour"
      invalid = get("/exercises", { limit: 1 }, key: KEY_PLACEHOLDER)
      puts "  Invalid key -> HTTP #{invalid.code}: #{invalid.body.to_s[0, 120]}"
      unknown = get("/exercises/exercise/definitely-not-a-real-id")
      puts "  Unknown id  -> HTTP #{unknown.code}: #{unknown.body.to_s[0, 120]}"
    end

    def write_fixtures
      section "Fixtures"
      @captured["exercises_sample.json"] = JSON.pretty_generate(@samples.first(3)) if @samples.any?
      if @captured.empty?
        puts "  Nothing captured."
        return
      end

      @captured.each do |name, content|
        path = WorkoutxProbe.fixture_dir.join(name)
        File.write(path, redact(content))
        puts "  wrote #{path.relative_path_from(Rails.root)}"
      end
      puts "  Review each file for a leaked key before committing."
    end

    private

    def get(path, params = {}, key: @key)
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?
      request = Net::HTTP::Get.new(uri)
      request["X-WorkoutX-Key"] = key
      request["Accept"] = "application/json"
      http(uri).request(request)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      abort "Timeout contacting provider: #{e.class}"
    end

    def inspect_gif(url)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["X-WorkoutX-Key"] = @key
      response = http(uri).request(request)

      body = response.body.to_s
      { status: response.code,
        mime: response["content-type"],
        bytes: body.bytesize,
        dimensions: gif_dimensions(body) }
    rescue StandardError => e
      { status: "error:#{e.class}", mime: nil, bytes: nil, dimensions: nil }
    end

    def anonymous_status(url)
      uri = URI(url)
      http(uri).request(Net::HTTP::Get.new(uri)).code
    rescue StandardError => e
      "error:#{e.class}"
    end

    # GIF87a/GIF89a store width and height as little-endian uint16 at bytes 6..9.
    def gif_dimensions(bytes)
      return nil unless bytes.start_with?("GIF8")
      width, height = bytes[6, 4].unpack("vv")
      "#{width}x#{height}"
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |client|
        client.use_ssl = uri.scheme == "https"
        client.open_timeout = OPEN_TIMEOUT
        client.read_timeout = READ_TIMEOUT
      end
    end

    def extract(body)
      Array(body.is_a?(Hash) ? (body["data"] || body["exercises"]) : body)
    end

    def json(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      abort "Non-JSON response (HTTP #{response.code}). Body withheld to avoid leaking headers."
    end

    def filled?(value)
      return false if value.nil?
      return !value.empty? if value.respond_to?(:empty?)
      true
    end

    def percentile(sorted, pct)
      sorted[[ (sorted.size * pct / 100.0).ceil - 1, 0 ].max]
    end

    # Defence in depth: strip the key even though it is never intentionally written.
    def redact(content)
      content.gsub(@key, "REDACTED").gsub(/wx_[A-Za-z0-9]{8,}/, "REDACTED")
    end

    def section(title)
      puts
      puts "== #{title}"
    end
  end
end

namespace :workoutx do
  desc "Stage 0: measure the WorkoutX dataset and record sanitized fixtures"
  task probe: :environment do
    key = ENV["WORKOUTX_API_KEY"].to_s.strip
    if key.empty?
      abort <<~MSG
        WORKOUTX_API_KEY is not set.

        Stage 0 cannot run without a provider key. Register for the Free plan
        (no credit card) at https://workoutxapp.com/ and re-run:

          WORKOUTX_API_KEY=... bin/rails workoutx:probe

        Do not paste the key into any file in this repository.
      MSG
    end

    sample_size = Integer(ENV.fetch("SAMPLE", 25))
    client = WorkoutxProbe::Client.new(key)

    # 1 plan headers + 1 coverage page + GIF_SAMPLE GIFs + 1 anonymous GIF check
    # + 3 pagination + 2 error behaviour (+ 1 optional /changes).
    metadata_calls = 1 + 1 + 3 + 2 + (ENV["CHANGES"] == "1" ? 1 : 0)
    gif_calls = WorkoutxProbe::GIF_SAMPLE + 1

    puts "WorkoutX Stage 0 probe"
    puts "Budget: #{metadata_calls} metadata requests + #{gif_calls} GIF requests " \
         "= #{metadata_calls + gif_calls} total. The Free plan allows 500/month."
    puts "The #{WorkoutxProbe::GIF_SAMPLE} GIFs are distinct exercises, so they may also"
    puts "consume #{WorkoutxProbe::GIF_SAMPLE} slots on the separate unique-GIF meter."
    puts "SAMPLE only changes the metadata page size, not the request count."

    client.report_plan_headers
    client.report_catalog_coverage(sample_size)
    client.report_gif_characteristics
    client.report_pagination_and_stable_ids
    client.report_changes_endpoint if ENV["CHANGES"] == "1"
    client.report_error_behaviour
    client.write_fixtures
  end
end
