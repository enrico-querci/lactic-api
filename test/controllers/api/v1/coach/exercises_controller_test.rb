require "test_helper"

class Api::V1::Coach::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @custom = exercises(:custom_exercise)
    @catalog = exercises(:bench_press)
  end

  # GET /api/v1/coach/exercises
  test "index returns catalog and coach's custom exercises" do
    get "/api/v1/coach/exercises", headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.size >= 4 # 3 catalog + 1 custom
  end

  test "index filters by muscle_group" do
    get "/api/v1/coach/exercises", params: { muscle_group: "Chest" }, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    json.each { |e| assert_equal "Chest", e["muscle_group"] }
  end

  test "index searches by name" do
    get "/api/v1/coach/exercises", params: { search: "bench" }, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.any? { |e| e["name"] == "Bench Press" }
  end

  test "index returns 403 for client role" do
    get "/api/v1/coach/exercises", headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # POST /api/v1/coach/exercises
  test "create adds a custom exercise" do
    assert_difference "Exercise.count", 1 do
      post "/api/v1/coach/exercises",
           params: { exercise: { name: "Custom Lift", muscle_group: "Back" } },
           headers: auth_headers_for(@coach)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Custom Lift", json["name"]
    assert json["is_custom"]
  end

  test "create returns 422 for missing name" do
    post "/api/v1/coach/exercises",
         params: { exercise: { name: "", muscle_group: "Back" } },
         headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  # PATCH /api/v1/coach/exercises/:id
  test "update modifies a custom exercise" do
    patch "/api/v1/coach/exercises/#{@custom.id}",
          params: { exercise: { name: "Renamed" } },
          headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal "Renamed", @custom.reload.name
  end

  test "update returns 404 for catalog exercise" do
    patch "/api/v1/coach/exercises/#{@catalog.id}",
          params: { exercise: { name: "Hacked" } },
          headers: auth_headers_for(@coach)
    assert_response :not_found
  end

  # DELETE /api/v1/coach/exercises/:id
  test "destroy deletes a custom exercise" do
    assert_difference "Exercise.count", -1 do
      delete "/api/v1/coach/exercises/#{@custom.id}", headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end

  test "destroy returns 404 for catalog exercise" do
    delete "/api/v1/coach/exercises/#{@catalog.id}", headers: auth_headers_for(@coach)
    assert_response :not_found
  end
end
