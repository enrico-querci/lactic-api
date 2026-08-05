require "test_helper"

class Api::V1::ExerciseAnimationsControllerTest < ActionDispatch::IntegrationTest
  GIF_BYTES = ("GIF89a" + "\x00\x01\x02\xFF".b * 64).b

  # Replaces the network. Every provider failure the acceptance criteria name
  # is driven from here rather than against the live API.
  class FakeTransport
    attr_reader :calls

    def initialize(response)
      @response = response
      @calls = []
    end

    def get_binary(url, headers: {}, max_bytes: nil)
      @calls << { url: url, headers: headers, max_bytes: max_bytes }
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  def binary_response(status: 200, body: GIF_BYTES, content_type: "image/gif")
    Catalog::Providers::HttpTransport::Response.new(
      status: status, body: body, headers: { "content-type" => content_type }
    )
  end

  # Matches the save/redefine/restore pattern the auth service tests already
  # use, rather than pulling in a mocking library for one file.
  def stub_provider(response, api_key: "test-key")
    transport = FakeTransport.new(response)
    provider = Catalog::Providers::WorkoutX.new(
      api_key: api_key, transport: transport, sleeper: ->(_) { }
    )
    with_provider(provider) { yield transport }
  end

  def with_provider(provider)
    original = Catalog::Providers::WorkoutX.method(:new)
    Catalog::Providers::WorkoutX.define_singleton_method(:new) { |**| provider }
    yield
  ensure
    Catalog::Providers::WorkoutX.define_singleton_method(:new, original)
  end

  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @exercise = exercises(:provider_situp)
  end

  def get_animation(user, exercise = @exercise, headers: {})
    get "/api/v1/exercises/#{exercise.id}/animation",
      headers: user ? auth_headers_for(user).merge(headers) : headers
  end

  # --- Happy path ---------------------------------------------------------

  test "an authenticated coach receives the animation bytes" do
    stub_provider(binary_response) do
      get_animation(@coach)
    end

    assert_response :ok
    assert_equal "image/gif", response.media_type
    assert_equal GIF_BYTES, response.body.b
    assert response.body.b.start_with?("GIF89a")
  end

  test "an authenticated client of the owning coach receives the animation" do
    stub_provider(binary_response) { get_animation(@client) }

    assert_response :ok
    assert_equal "image/gif", response.media_type
  end

  test "the provider key is sent as a header, never in the url" do
    calls = nil
    stub_provider(binary_response) do |transport|
      get_animation(@coach)
      calls = transport.calls
    end

    assert_equal "test-key", calls.first[:headers]["X-WorkoutX-Key"]
    assert_not_includes calls.first[:url], "test-key"
    assert_not_includes calls.first[:url], "api-key"
  end

  test "a maximum response size is enforced on the upstream fetch" do
    calls = nil
    stub_provider(binary_response) do |transport|
      get_animation(@coach)
      calls = transport.calls
    end

    assert_equal Catalog::Providers::WorkoutX::ANIMATION_MAX_BYTES, calls.first[:max_bytes]
  end

  test "no credential or upstream url reaches the client" do
    stub_provider(binary_response) { get_animation(@coach) }

    body_and_headers = response.body.b + response.headers.to_h.to_s
    assert_not_includes body_and_headers, "test-key"
    assert_not_includes body_and_headers, "X-WorkoutX-Key"
    assert_not_includes body_and_headers, "workoutxapp"
  end

  test "responses are not cached while caching permission is unresolved" do
    stub_provider(binary_response) { get_animation(@coach) }

    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  # --- Authentication and authorization -----------------------------------

  test "an unauthenticated request is rejected without contacting the provider" do
    calls = nil
    stub_provider(binary_response) do |transport|
      get_animation(nil)
      calls = transport.calls
    end

    assert_response :unauthorized
    assert_empty calls, "must not reach upstream before authenticating"
  end

  test "another coach cannot fetch an exercise they cannot see" do
    other = User.create!(name: "Other", email: "other@example.com", role: "coach")
    custom = exercises(:custom_exercise)

    stub_provider(binary_response) { get_animation(other, custom) }

    assert_response :not_found
  end

  test "a deactivated exercise still resolves, so history keeps rendering" do
    @exercise.update!(active: false, assignable: false)

    stub_provider(binary_response) { get_animation(@coach) }

    assert_response :ok
  end

  # --- Missing media ------------------------------------------------------

  test "an exercise with no media returns not found without contacting the provider" do
    calls = nil
    stub_provider(binary_response) do |transport|
      get_animation(@coach, exercises(:bench_press))
      calls = transport.calls
    end

    assert_response :not_found
    assert_empty calls
  end

  test "a media row with a blank provider url is not resolved" do
    @exercise.exercise_media.update_all(provider_url: nil)

    stub_provider(binary_response) { get_animation(@coach) }

    assert_response :not_found
  end

  # --- Upstream failures --------------------------------------------------

  test "an upstream 401 becomes a stable bad gateway, not a 401 to the client" do
    stub_provider(binary_response(status: 401, content_type: "application/json")) do
      get_animation(@coach)
    end

    # A 401 here would tell the client their own session expired, which is
    # false and would trigger the web client's token refresh.
    assert_response :bad_gateway
    assert_equal "Animation unavailable", JSON.parse(response.body)["error"]
  end

  test "an upstream 429 becomes service unavailable" do
    stub_provider(binary_response(status: 429, content_type: "application/json")) do
      get_animation(@coach)
    end

    assert_response :service_unavailable
  end

  test "an upstream 5xx becomes bad gateway" do
    stub_provider(binary_response(status: 503, content_type: "application/json")) do
      get_animation(@coach)
    end

    assert_response :bad_gateway
  end

  test "a timeout becomes bad gateway" do
    stub_provider(Catalog::Providers::Errors::Transient.new("network failure: Net::ReadTimeout")) do
      get_animation(@coach)
    end

    assert_response :bad_gateway
  end

  test "an oversized response becomes bad gateway" do
    stub_provider(Catalog::Providers::Errors::Schema.new("response exceeded 8000000 bytes")) do
      get_animation(@coach)
    end

    assert_response :bad_gateway
  end

  test "an unexpected content type is refused rather than passed through" do
    stub_provider(binary_response(body: "<html>login</html>".b, content_type: "text/html")) do
      get_animation(@coach)
    end

    assert_response :bad_gateway
    assert_not_includes response.body, "<html>"
  end

  test "an empty body is refused" do
    stub_provider(binary_response(body: "".b)) { get_animation(@coach) }

    assert_response :bad_gateway
  end

  test "a failure response is also uncacheable" do
    stub_provider(binary_response(status: 503, content_type: "application/json")) do
      get_animation(@coach)
    end

    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "no provider error message leaks to the client" do
    stub_provider(binary_response(status: 401, content_type: "application/json")) do
      get_animation(@coach)
    end

    assert_not_includes response.body, "401"
    assert_not_includes response.body, "credentials"
  end

  # --- Key handling -------------------------------------------------------

  test "a missing api key fails closed rather than fetching anonymously" do
    calls = nil
    stub_provider(binary_response, api_key: nil) do |transport|
      get_animation(@coach)
      calls = transport.calls
    end

    assert_response :bad_gateway
    assert_empty calls, "must not attempt an anonymous fetch"
  end

  test "the key is never attached to a url outside the provider" do
    @exercise.exercise_media.update_all(provider_url: "https://evil.example.com/steal.gif")
    calls = nil

    stub_provider(binary_response) do |transport|
      get_animation(@coach)
      calls = transport.calls
    end

    assert_response :bad_gateway
    assert_empty calls, "must not send the credential to a non-provider host"
  end
end
