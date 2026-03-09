require "test_helper"

class Api::V1::Coach::ProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @program = programs(:strength_program)
  end

  # GET /api/v1/coach/programs
  test "index returns coach's programs" do
    get "/api/v1/coach/programs", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |p| p["id"] == @program.id }
  end

  test "index returns 403 for client" do
    get "/api/v1/coach/programs", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  test "index returns 401 without token" do
    get "/api/v1/coach/programs"
    assert_response :unauthorized
  end

  # GET /api/v1/coach/programs/:id
  test "show returns program with weeks" do
    get "/api/v1/coach/programs/#{@program.id}", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @program.name, json["name"]
    assert json.key?("weeks")
  end

  test "show returns 404 for non-owned program" do
    other_coach = User.create!(name: "Other Coach", email: "other_coach@example.com", role: "coach")
    other_program = Program.create!(name: "Other", coach: other_coach)
    get "/api/v1/coach/programs/#{other_program.id}", headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # POST /api/v1/coach/programs
  test "create adds a program" do
    assert_difference "Program.count", 1 do
      post "/api/v1/coach/programs",
           params: { program: { name: "New Program", description: "Test" } },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "New Program", json["name"]
  end

  test "create returns 422 for missing name" do
    post "/api/v1/coach/programs",
         params: { program: { name: "", description: "Test" } },
         headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  # PATCH /api/v1/coach/programs/:id
  test "update modifies a program" do
    patch "/api/v1/coach/programs/#{@program.id}",
          params: { program: { name: "Updated" } },
          headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal "Updated", @program.reload.name
  end

  # DELETE /api/v1/coach/programs/:id
  test "destroy deletes a program" do
    program = Program.create!(name: "To Delete", coach: @coach)
    assert_difference "Program.count", -1 do
      delete "/api/v1/coach/programs/#{program.id}", headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end
end
