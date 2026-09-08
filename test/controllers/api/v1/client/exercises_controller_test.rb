require "test_helper"

class Api::V1::Client::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @client = users(:client_alice)
    @bench = exercises(:bench_press)
  end

  # GET index
  test "index returns catalog and coach's custom exercises" do
    get "/api/v1/client/exercises", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.size >= 4
  end

  test "index filters by muscle_group" do
    get "/api/v1/client/exercises", params: { muscle_group: "Chest" }, headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    json.each { |e| assert_equal "Chest", e["muscle_group"] }
  end

  test "index returns 403 for coach" do
    get "/api/v1/client/exercises", headers: auth_headers_for(@coach)
    assert_response :forbidden
  end

  # GET show
  test "show returns an exercise" do
    get "/api/v1/client/exercises/#{@bench.id}", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @bench.name, json["name"]
  end

  # GET history
  test "history returns set logs for exercise" do
    get "/api/v1/client/exercises/#{@bench.id}/history", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert json.size >= 2
  end

  test "history returns empty for exercise with no logs" do
    squat = exercises(:squat)
    get "/api/v1/client/exercises/#{squat.id}/history", headers: auth_headers_for(@client)
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal 0, json.size
  end

  # SetLog includes Positionable, whose default_scope orders by position. That
  # scope is applied before anything the controller asks for, so an `order`
  # call only appends and never gets to sort — every session's sets interleaved
  # by set number instead of grouping newest-session-first. Nothing caught it
  # because the fixtures hold a single session, where the two orderings agree.
  # This test needs two sessions on different dates to tell them apart.
  test "history groups sets newest session first, not by set number" do
    # Offset from the fixture's own timestamp rather than from Time.current:
    # the fixture session is dated 2026-03-01, so `30.days.ago` would have made
    # this the NEWER of the two and quietly inverted what the test asserts.
    recent_session = workout_sessions(:alice_chest_session)
    older = WorkoutSession.create!(
      client: @client,
      workout: workouts(:chest_day),
      program_assignment: program_assignments(:alice_strength),
      started_at: recent_session.started_at - 30.days
    )
    older_log = older.exercise_logs.create!(workout_exercise: workout_exercises(:bench_in_chest_day))
    older_first = older_log.set_logs.create!(position: 1, weight_kg: 40, reps: 12)
    older_second = older_log.set_logs.create!(position: 2, weight_kg: 40, reps: 11)

    # The fixture session is the recent one.
    recent_first = set_logs(:bench_set_one)
    recent_second = set_logs(:bench_set_two)

    get "/api/v1/client/exercises/#{@bench.id}/history", headers: auth_headers_for(@client)
    assert_response :ok
    ids = JSON.parse(response.body).map { |s| s["id"] }

    assert_equal [ recent_first.id, recent_second.id, older_first.id, older_second.id ], ids,
                 "expected both sets of the newest session before either set of the older one"
  end
end
