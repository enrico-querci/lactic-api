require "test_helper"

# Pins the API's datetime encoding across BOTH rendering paths.
#
# Blueprinter renders through JSON.generate, which bypasses ActiveSupport's
# encoder; a handful of actions instead render a plain Hash, which does not.
# Left to their defaults those two paths disagree ("2026-03-01 10:00:00 UTC"
# vs "2026-03-01T10:00:00.000Z"), and which one a client saw depended on how
# the controller happened to render rather than on anything in the contract.
# config/initializers/blueprinter.rb settles it; these tests keep it settled,
# because nothing else in the suite asserts on a serialized datetime and the
# next Blueprinter upgrade or initializer edit would otherwise change the wire
# format for every client silently.
class Api::V1::DatetimeSerializationTest < ActionDispatch::IntegrationTest
  # "2026-03-01T10:00:00.000Z" — ISO 8601, milliseconds, UTC.
  ISO8601_MS = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/
  DATE_ONLY  = /\A\d{4}-\d{2}-\d{2}\z/

  setup do
    @client = users(:client_alice)
    @program = programs(:strength_program)
    @session = workout_sessions(:alice_chest_session)
  end

  test "a Blueprint-rendered datetime is ISO 8601 with milliseconds in UTC" do
    get "/api/v1/client/workout_sessions", headers: auth_headers_for(@client)
    assert_response :ok

    row = JSON.parse(response.body).find { |s| s["id"] == @session.id }
    assert row, "expected the fixture session in the response"
    assert_equal "2026-03-01T10:00:00.000Z", row["started_at"]
    assert_equal "2026-03-01T11:00:00.000Z", row["completed_at"]
  end

  test "a nested Blueprint datetime is formatted the same way" do
    get "/api/v1/client/programs", headers: auth_headers_for(@client)
    assert_response :ok

    row = JSON.parse(response.body).find { |a| a["program"]["id"] == @program.id }
    assert_match ISO8601_MS, row["program"]["created_at"]
    assert_equal @program.created_at.iso8601(3), row["program"]["created_at"]
  end

  # A Date has no time component. DateTime subclasses Date, so a formatter that
  # forgets to exclude it would raise ArgumentError here (Date#iso8601 takes no
  # precision argument) or widen a plain date into a bogus timestamp.
  test "a date column stays date-only" do
    get "/api/v1/client/programs", headers: auth_headers_for(@client)
    assert_response :ok

    row = JSON.parse(response.body).find { |a| a["program"]["id"] == @program.id }
    assert_match DATE_ONLY, row["start_date"]
    assert_equal "2026-03-01", row["start_date"]
  end

  # The regression this whole initializer exists to prevent: the two rendering
  # paths must not drift apart again.
  test "the Hash-rendered path agrees with the Blueprint-rendered path" do
    get "/api/v1/client/programs", headers: auth_headers_for(@client)
    from_blueprint = JSON.parse(response.body)
      .find { |a| a["program"]["id"] == @program.id }
      .dig("program", "created_at")

    # client/programs#show merges a Blueprint hash into a plain Hash and lets
    # ActiveSupport encode the result, so it exercises the other path.
    get "/api/v1/client/programs/#{@program.id}", headers: auth_headers_for(@client)
    assert_response :ok
    from_hash = JSON.parse(response.body)["created_at"]

    assert_match ISO8601_MS, from_hash
    assert_equal from_blueprint, from_hash
  end
end
