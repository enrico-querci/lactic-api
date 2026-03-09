require "test_helper"

class Api::V1::Coach::WeeksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @program = programs(:strength_program)
    @week = weeks(:week_one)
  end

  def weeks_url
    "/api/v1/coach/programs/#{@program.id}/weeks"
  end

  def week_url(week = @week)
    "#{weeks_url}/#{week.id}"
  end

  # GET /api/v1/coach/programs/:program_id/weeks
  test "index returns weeks for a program" do
    get weeks_url, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 2, json.size
  end

  test "index returns 403 for client" do
    get weeks_url, headers: auth_headers_for(@client)
    assert_response :forbidden
  end

  # GET /api/v1/coach/programs/:program_id/weeks/:id
  test "show returns week with workouts" do
    get week_url, headers: auth_headers_for(@coach)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.key?("workouts")
  end

  # POST /api/v1/coach/programs/:program_id/weeks
  test "create adds a week" do
    assert_difference "Week.count", 1 do
      post weeks_url, params: { week: { position: 3 } }, headers: auth_headers_for(@coach)
    end
    assert_response :created
  end

  test "create returns 422 for duplicate position" do
    post weeks_url, params: { week: { position: 1 } }, headers: auth_headers_for(@coach)
    assert_response :unprocessable_entity
  end

  # PATCH /api/v1/coach/programs/:program_id/weeks/:id
  test "update changes week position" do
    week_two = weeks(:week_two)
    patch week_url(week_two), params: { week: { position: 5 } }, headers: auth_headers_for(@coach)
    assert_response :ok
    assert_equal 5, week_two.reload.position
  end

  # DELETE /api/v1/coach/programs/:program_id/weeks/:id
  test "destroy deletes a week" do
    week = @program.weeks.create!(position: 99)
    assert_difference "Week.count", -1 do
      delete week_url(week), headers: auth_headers_for(@coach)
    end
    assert_response :no_content
  end
end
