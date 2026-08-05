require "test_helper"

# Stage 5: the localized exercise contract. Kept separate from the original
# exercises_controller_test so that file stays the record of the pre-Stage-5
# behaviour that must not regress.
class Api::V1::Coach::ExercisesLocalizedTest < ActionDispatch::IntegrationTest
  setup do
    @coach = users(:coach_john)
    @situp = exercises(:provider_situp)
    @treadmill = exercises(:provider_treadmill)
  end

  def get_index(params: {}, headers: {})
    get "/api/v1/coach/exercises", params: params, headers: auth_headers_for(@coach).merge(headers)
    JSON.parse(response.body)
  end

  def find_row(json, id) = json.find { |row| row["id"] == id }

  # --- Localization -------------------------------------------------------

  test "uses the user's stored locale preference" do
    @coach.update!(locale: "it")
    json = get_index

    assert_equal "Sit-up 3/4", find_row(json, @situp.id)["name"]
  end

  test "falls back to Accept-Language when the user has no preference" do
    assert_nil @coach.locale
    json = get_index(headers: { "Accept-Language" => "it-IT,it;q=0.9,en;q=0.8" })

    assert_equal "Sit-up 3/4", find_row(json, @situp.id)["name"]
  end

  test "the user's preference wins over Accept-Language" do
    @coach.update!(locale: "en")
    json = get_index(headers: { "Accept-Language" => "it" })

    assert_equal "3/4 Sit-up", find_row(json, @situp.id)["name"]
  end

  test "honours Accept-Language quality ordering" do
    json = get_index(headers: { "Accept-Language" => "en;q=0.2,it;q=0.9" })

    assert_equal "Sit-up 3/4", find_row(json, @situp.id)["name"]
  end

  test "ignores an unsupported language and serves english" do
    json = get_index(headers: { "Accept-Language" => "de-DE,de;q=0.9" })

    assert_equal "3/4 Sit-up", find_row(json, @situp.id)["name"]
  end

  test "defaults to english with no preference and no header" do
    assert_equal "3/4 Sit-up", find_row(get_index, @situp.id)["name"]
  end

  test "falls back to english for an exercise with no italian translation" do
    @coach.update!(locale: "it")
    @situp.exercise_translations.for_locale("it").destroy_all

    assert_equal "3/4 Sit-up", find_row(get_index, @situp.id)["name"]
  end

  test "falls back to the legacy column for an exercise with no translations" do
    @coach.update!(locale: "it")
    json = get_index

    assert_equal "Bench Press", find_row(json, exercises(:bench_press).id)["name"]
  end

  test "detail reports the locale actually served" do
    @coach.update!(locale: "it")

    get "/api/v1/coach/exercises/#{@situp.id}", headers: auth_headers_for(@coach)
    assert_equal "it", JSON.parse(response.body)["locale"]

    @situp.exercise_translations.for_locale("it").destroy_all
    get "/api/v1/coach/exercises/#{@situp.id}", headers: auth_headers_for(@coach)
    assert_equal "en", JSON.parse(response.body)["locale"]
  end

  # --- Contract -----------------------------------------------------------

  test "list omits instructions but detail includes them" do
    row = find_row(get_index, @situp.id)
    assert_not row.key?("instructions")
    assert_not row.key?("secondary_muscles")

    get "/api/v1/coach/exercises/#{@situp.id}", headers: auth_headers_for(@coach)
    detail = JSON.parse(response.body)
    assert_equal 3, detail["instructions"].size
    assert_equal [ "Hip Flexors", "Lower Back" ], detail["secondary_muscles"].map { |m| m["name"] }
  end

  test "serializes the normalized muscle and equipment contract" do
    row = find_row(get_index, @situp.id)

    assert_equal({ "key" => "abs", "name" => "Abs", "region" => "Waist" }, row["primary_muscle"])
    assert_equal [ { "key" => "body_weight", "name" => "Body Weight" } ], row["equipment"]
  end

  test "animation_url points at lactic and never at the provider" do
    row = find_row(get_index, @situp.id)

    assert row["has_animation"]
    assert_equal "/api/v1/exercises/#{@situp.id}/animation", row["animation_url"]
    assert_not_includes response.body, "workoutxapp"
    assert_not_includes response.body, "provider_url"
  end

  test "an exercise with no media reports no animation" do
    row = find_row(get_index, exercises(:bench_press).id)

    assert_not row["has_animation"]
    assert_nil row["animation_url"]
  end

  test "legacy fields are still emitted so the deployed web client keeps working" do
    row = find_row(get_index, @situp.id)

    assert row.key?("muscle_group")
    assert row.key?("video_url")
    assert row.key?("thumbnail_url")
    assert row.key?("is_custom")
  end

  # --- Assignability ------------------------------------------------------

  test "index excludes unassignable exercises by default" do
    assert_nil find_row(get_index, @treadmill.id)
  end

  test "include_unassignable widens the picker" do
    json = get_index(params: { include_unassignable: "true" })

    assert_not_nil find_row(json, @treadmill.id)
  end

  test "show still resolves an unassignable exercise so history keeps working" do
    get "/api/v1/coach/exercises/#{@treadmill.id}", headers: auth_headers_for(@coach)

    assert_response :ok
    assert_equal @treadmill.id, JSON.parse(response.body)["id"]
  end

  # --- Pagination ---------------------------------------------------------

  test "emits pagination headers while the body stays a bare array" do
    json = get_index(params: { per_page: 2 })

    assert_kind_of Array, json
    assert_equal 2, json.size
    assert_equal "2", response.headers["X-Per-Page"]
    assert_equal "1", response.headers["X-Page"]
    assert_operator response.headers["X-Total-Count"].to_i, :>=, 3
    assert_operator response.headers["X-Total-Pages"].to_i, :>=, 2
  end

  test "pages do not overlap" do
    first = get_index(params: { per_page: 2, page: 1 }).map { |r| r["id"] }
    second = get_index(params: { per_page: 2, page: 2 }).map { |r| r["id"] }

    assert_empty(first & second)
  end

  # --- Filters and search -------------------------------------------------

  test "search works across locales regardless of response locale" do
    assert_not_nil find_row(get_index(params: { search: "Sit-up" }), @situp.id)
    assert_not_nil find_row(get_index(params: { search: "Sit-up 3/4" }), @situp.id)
  end

  test "filters by normalized muscle and equipment keys" do
    assert_not_nil find_row(get_index(params: { muscle: "abs" }), @situp.id)
    assert_not_nil find_row(get_index(params: { equipment: "body_weight" }), @situp.id)
    assert_nil find_row(get_index(params: { equipment: "barbell" }), @situp.id)
  end

  test "another coach cannot see this coach's custom exercise" do
    other = User.create!(name: "Other", email: "other@example.com", role: "coach")
    get "/api/v1/coach/exercises", headers: auth_headers_for(other)
    json = JSON.parse(response.body)

    assert_nil find_row(json, exercises(:custom_exercise).id)
  end

  test "another coach cannot fetch this coach's custom exercise by id" do
    other = User.create!(name: "Other", email: "other@example.com", role: "coach")

    get "/api/v1/coach/exercises/#{exercises(:custom_exercise).id}", headers: auth_headers_for(other)

    assert_response :not_found
  end

  # --- Query efficiency ---------------------------------------------------

  test "a page does not issue a query per exercise" do
    queries = 0
    counter = ->(_, _, _, _, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get_index }

    # Bounded rather than exact: the point is that adding exercises must not
    # add queries. Without eager loading this grows with the page size.
    assert_operator queries, :<, 25, "expected eager loading, saw #{queries} queries"
  end
end
