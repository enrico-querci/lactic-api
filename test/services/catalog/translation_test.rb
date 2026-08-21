require "test_helper"

module Catalog
  module Translation
    class GlossaryTest < ActiveSupport::TestCase
      test "returns the canonical italian term" do
        assert_equal "Addominali", Glossary.muscle("Abs")
        assert_equal "Dorsali", Glossary.muscle("Lats")
        assert_equal "Corpo libero", Glossary.equipment("Body Weight")
        assert_equal "addome", Glossary.region("Waist")
        assert_equal "forza", Glossary.category("strength")
        assert_equal "principiante", Glossary.difficulty("beginner")
      end

      test "an unknown term falls back to english rather than guessing" do
        # Visible and fixable, instead of silently becoming something wrong.
        assert_equal "Unobtainium", Glossary.muscle("Unobtainium")
        assert_equal "jetpack", Glossary.category("jetpack")
      end

      test "taxonomy values are matched case-insensitively where the provider lowercases them" do
        assert_equal "forza", Glossary.category("STRENGTH")
        assert_equal "avanzato", Glossary.difficulty("Advanced")
      end

      test "blank input returns nil" do
        assert_nil Glossary.muscle(nil)
        assert_nil Glossary.equipment("")
      end

      test "covers every muscle the provider can send as a primary target" do
        # The 19 published targets, from the checked-in taxonomy file.
        keys = YAML.safe_load_file(Rails.root.join("db/catalog_taxonomy.yml")).fetch("muscles")
        missing = keys.map { |m| m.fetch("name") }.reject { |name| Glossary.covers_muscle?(name) }

        assert_empty missing, "glossary is missing italian for: #{missing.inspect}"
      end

      test "covers every seeded equipment value" do
        items = YAML.safe_load_file(Rails.root.join("db/catalog_taxonomy.yml")).fetch("equipment")
        missing = items.map { |e| e.fetch("name") }.reject { |name| Glossary.covers_equipment?(name) }

        assert_empty missing, "glossary is missing italian for: #{missing.inspect}"
      end

      test "covers every legacy muscle_group value alongside the provider vocabulary" do
        legacy = %w[Back Chest Full\ Body Quadriceps Shoulders]
        missing = legacy.reject { |name| Glossary.covers_muscle?(name) }

        assert_empty missing, "glossary is missing italian for legacy value(s): #{missing.inspect}"
      end

      test "Chest and Pectorals intentionally alias the same italian term" do
        # Two English vocabularies (hand-seeded exercises vs. the provider
        # import) both describe the same muscle. A future "cleanup" that
        # removes the duplicate-looking Chest entry would silently break
        # Catalog::Translation::TaxonomyLabels.volume_sets, which relies on
        # both resolving identically to merge a mixed workout into one badge.
        assert_equal Glossary.muscle("Pectorals"), Glossary.muscle("Chest")
      end

      test "Quadriceps and Quads intentionally alias the same italian term" do
        assert_equal Glossary.muscle("Quads"), Glossary.muscle("Quadriceps")
      end
    end

    class DescriptionBuilderTest < ActiveSupport::TestCase
      setup { @exercise = exercises(:provider_situp) }

      test "composes a description from the exercise's own taxonomy" do
        text = DescriptionBuilder.call(@exercise, name: "Sit-up 3/4")

        assert_includes text, "Sit-up 3/4 è un esercizio"
        assert_includes text, "principiante di isolamento di spinta"
        assert_includes text, "coinvolge Addominali"
        assert_includes text, "nella zona addome"
        assert_includes text, "Si esegue con Corpo libero"
        assert_includes text, "categoria forza"
        assert_includes text, "Flessori dell'anca e Zona lombare"
      end

      test "uses the italian connector rather than a comma-and" do
        text = DescriptionBuilder.call(@exercise, name: "Test")

        assert_includes text, "Flessori dell'anca e Zona lombare"
        assert_not_includes text, ", and "
      end

      test "returns nil without a primary muscle, rather than a half sentence" do
        @exercise.exercise_muscles.destroy_all

        assert_nil DescriptionBuilder.call(@exercise.reload, name: "Test")
      end

      test "omits the equipment clause when there is none" do
        @exercise.exercise_equipment.destroy_all
        text = DescriptionBuilder.call(@exercise.reload, name: "Test")

        assert_includes text, "categoria forza"
        assert_not_includes text, "Si esegue con"
      end

      test "omits the secondary clause when there are none" do
        @exercise.exercise_muscles.secondary.destroy_all
        text = DescriptionBuilder.call(@exercise.reload, name: "Test")

        assert_not_includes text, "muscoli secondari"
      end
    end

    class GoogleAdapterTest < ActiveSupport::TestCase
      # Data rather than Struct: Array() calls to_a on a Struct, which would
      # splat a single response into [code, body].
      FakeResponse = Data.define(:code, :body)

      class FakeHttp
        attr_reader :requests

        def initialize(responses)
          @responses = responses.is_a?(::Array) ? responses.dup : [ responses ]
          @requests = []
        end

        def request(uri, request)
          @requests << { uri: uri, body: JSON.parse(request.body) }
          @responses.size > 1 ? @responses.shift : @responses.first
        end
      end

      def response(code, body)
        FakeResponse.new(code: code.to_s, body: body)
      end

      def ok(*texts)
        response(200, JSON.generate(data: { translations: texts.map { |t| { translatedText: t } } }))
      end

      def build(responses, api_key: "test-key")
        GoogleAdapter.new(api_key: api_key, http: FakeHttp.new(responses))
      end

      test "translates and returns results in order" do
        adapter = build(ok("uno", "due"))

        assert_equal %w[uno due], adapter.translate(%w[one two], to: "it")
      end

      test "sends source, target and plain text format" do
        http = FakeHttp.new(ok("uno"))
        GoogleAdapter.new(api_key: "k", http: http).translate([ "one" ], to: "it")

        body = http.requests.first[:body]
        assert_equal [ "one" ], body["q"]
        assert_equal "it", body["target"]
        assert_equal "en", body["source"]
        assert_equal "text", body["format"]
      end

      test "does not leak the key through inspect" do
        adapter = build(ok("uno"), api_key: "super-secret")

        assert_not_includes adapter.inspect, "super-secret"
        assert_includes adapter.inspect, "configured=true"
      end

      test "is not configured without a key and refuses to call" do
        adapter = GoogleAdapter.new(api_key: nil, http: FakeHttp.new(ok("uno")))

        assert_not adapter.configured?
        assert_raises(Errors::NotConfigured) { adapter.translate([ "one" ], to: "it") }
      end

      test "an empty input makes no request" do
        http = FakeHttp.new(ok("uno"))

        assert_empty GoogleAdapter.new(api_key: "k", http: http).translate([], to: "it")
        assert_empty http.requests
      end

      test "splits into batches when the segment limit is exceeded" do
        http = FakeHttp.new([ ok(*Array.new(100, "x")), ok("x") ])
        GoogleAdapter.new(api_key: "k", http: http).translate(Array.new(101, "one"), to: "it")

        assert_equal 2, http.requests.size
        assert_equal 100, http.requests.first[:body]["q"].size
        assert_equal 1, http.requests.last[:body]["q"].size
      end

      test "splits into batches when the character limit is exceeded" do
        long = "a" * 15_000
        http = FakeHttp.new([ ok("x"), ok("x") ])
        GoogleAdapter.new(api_key: "k", http: http).translate([ long, long ], to: "it")

        assert_equal 2, http.requests.size
      end

      test "maps provider failures onto the shared error types" do
        assert_raises(Errors::Rejected) { build(response(403, "{}")).translate([ "a" ], to: "it") }
        assert_raises(Errors::Rejected) { build(response(429, "{}")).translate([ "a" ], to: "it") }
        assert_raises(Errors::Transient) { build(response(503, "{}")).translate([ "a" ], to: "it") }
        assert_raises(Errors::Schema) { build(response(418, "{}")).translate([ "a" ], to: "it") }
      end

      test "unparseable json is a schema error and does not echo the body" do
        error = assert_raises(Errors::Schema) do
          build(response(200, "<html>error</html>")).translate([ "a" ], to: "it")
        end

        assert_not_includes error.message, "html"
      end

      test "a misaligned response is refused rather than silently reordering steps" do
        assert_raises(Errors::Schema) do
          build(ok("only one")).translate(%w[one two three], to: "it")
        end
      end
    end
  end
end
