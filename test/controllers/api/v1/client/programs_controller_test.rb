require "test_helper"

class Api::V1::Client::ProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @program = programs(:strength_program)
  end

  # GET index
  test "index returns client's assigned programs" do
    get "/api/v1/client/programs", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |p| p["id"] == @program.id }
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

  test "show returns 404 for unassigned program" do
    other_coach = User.create!(name: "Other", email: "other_c@example.com", role: "coach")
    other_program = Program.create!(name: "Other", coach: other_coach)
    get "/api/v1/client/programs/#{other_program.id}", headers: auth_headers_for(@client)
    assert_response :not_found
  end
end
