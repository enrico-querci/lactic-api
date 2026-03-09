require "test_helper"

class Api::V1::Coach::ProgramAssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @client_bob = users(:client_bob)
    @program = programs(:strength_program)
    @assignment = program_assignments(:alice_strength)
  end

  # GET index
  test "index returns coach's assignments" do
    get "/api/v1/coach/program_assignments", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |a| a["id"] == @assignment.id }
  end

  test "index filters by client_id" do
    get "/api/v1/coach/program_assignments", params: { client_id: @client.id }, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    json.each { |a| assert_equal @client.id, a["client"]["id"] }
  end

  test "index filters by status" do
    get "/api/v1/coach/program_assignments", params: { status: "active" }, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    json.each { |a| assert_equal "active", a["status"] }
  end

  test "index returns 403 for client" do
    get "/api/v1/coach/program_assignments", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET show
  test "show returns an assignment" do
    get "/api/v1/coach/program_assignments/#{@assignment.id}", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @assignment.id, json["id"]
  end

  # POST create
  test "create assigns program to client" do
    assert_difference "ProgramAssignment.count", 1 do
      post "/api/v1/coach/program_assignments",
           params: { program_assignment: {
             program_id: @program.id,
             client_id: @client_bob.id,
             start_date: "2026-04-01",
             status: "active"
           } },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
  end

  test "create returns 422 for missing start_date" do
    post "/api/v1/coach/program_assignments",
         params: { program_assignment: { program_id: @program.id, client_id: @client_bob.id } },
         headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  # PATCH update
  test "update changes assignment status" do
    patch "/api/v1/coach/program_assignments/#{@assignment.id}",
          params: { program_assignment: { status: "paused" } },
          headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal "paused", @assignment.reload.status
  end

  # DELETE destroy
  test "destroy deletes an assignment" do
    assignment = ProgramAssignment.create!(
      program: @program, client: @client_bob, coach: @coach,
      start_date: "2026-05-01", status: "active"
    )
    assert_difference "ProgramAssignment.count", -1 do
      delete "/api/v1/coach/program_assignments/#{assignment.id}", headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end
end
