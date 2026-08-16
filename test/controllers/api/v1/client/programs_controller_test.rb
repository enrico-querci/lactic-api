require "test_helper"

class Api::V1::Client::ProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @program = programs(:strength_program)
  end

  # GET index
  #
  # The web client (lib/api/types.ts) has always declared this endpoint as
  # ProgramAssignment[], reading status/start_date/notes off each row to
  # render a badge and a subtitle. Asserting only p["id"] against the
  # program's own id let a prior version accidentally pass while returning
  # bare Program[] instead — self-consistent with the bug, not a check
  # against the real cross-repo contract. These assertions pin that shape.
  test "index returns the client's assignments, not bare programs" do
    get "/api/v1/client/programs", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)

    row = json.find { |a| a["program"]["id"] == @program.id }
    assert row, "expected an assignment wrapping program #{@program.id}"
    assert_equal program_assignments(:alice_strength).id, row["id"]
    assert_equal "active", row["status"]
    assert_equal "2026-03-01", row["start_date"]
    assert_equal @program.name, row["program"]["name"]
  end

  test "index omits a paused or completed assignment" do
    program_assignments(:alice_strength).update!(status: :paused)

    get "/api/v1/client/programs", headers: auth_headers_for(@client)
    json = JSON.parse(response.body)

    assert_not json.any? { |a| a["program"]["id"] == @program.id }
  end

  test "index returns 403 for coach" do
    get "/api/v1/client/programs", headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  test "index returns 401 without token" do
    get "/api/v1/client/programs"
    assert_response :unauthorized
  end

  # GET show
  test "show returns program with weeks and workouts" do
    get "/api/v1/client/programs/#{@program.id}", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @program.name, json["name"]
    assert json.key?("weeks")
  end

  # Without assignment_id, the web client cannot start a workout session:
  # WorkoutSession belongs to a specific ProgramAssignment, not just a
  # Program, and nothing about a workout_id alone identifies which
  # assignment a session belongs to. Its absence here previously meant no
  # client could ever start a workout — every session create silently sent
  # program_assignment_id: 0 and the server correctly rejected it.
  test "show includes the client's assignment id for this program" do
    get "/api/v1/client/programs/#{@program.id}", headers: auth_headers_for(@client)
    json = JSON.parse(response.body)

    assert_equal program_assignments(:alice_strength).id, json["assignment_id"]
  end

  test "show returns 404 for unassigned program" do
    other_coach = User.create!(name: "Other", email: "other_c@example.com", role: "coach")
    other_program = Program.create!(name: "Other", coach: other_coach)
    get "/api/v1/client/programs/#{other_program.id}", headers: auth_headers_for(@client)
    assert_response :not_found
  end
end
