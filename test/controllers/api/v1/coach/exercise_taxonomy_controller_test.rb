require "test_helper"

class Api::V1::Coach::ExerciseTaxonomyControllerTest < ActionDispatch::IntegrationTest
  setup { @coach = users(:coach_john) }

  def taxonomy(headers: {})
    get "/api/v1/coach/exercise_taxonomy", headers: auth_headers_for(@coach).merge(headers)
    JSON.parse(response.body)
  end

  test "requires authentication" do
    get "/api/v1/coach/exercise_taxonomy"
    assert_response :unauthorized
  end

  test "returns muscles with their stable keys and regions" do
    abs = taxonomy["muscles"].find { |m| m["key"] == "abs" }

    assert_equal "Abs", abs["name"]
    assert_equal "Waist", abs["region"]
  end

  test "returns equipment with stable keys" do
    assert_includes taxonomy["equipment"], { "key" => "body_weight", "name" => "Body Weight" }
  end

  test "keys match what the filters expect" do
    # A key returned here must actually filter, otherwise the UI offers a
    # control that silently returns nothing.
    taxonomy["muscles"].each do |muscle|
      result = Catalog::ExerciseSearch.call(scope: Exercise.all, params: { muscle: muscle["key"] })
      assert_operator result.total_count, :>, 0, "muscle #{muscle['key']} filters to nothing"
    end

    taxonomy["equipment"].each do |item|
      result = Catalog::ExerciseSearch.call(scope: Exercise.all, params: { equipment: item["key"] })
      assert_operator result.total_count, :>, 0, "equipment #{item['key']} filters to nothing"
    end
  end

  test "omits taxonomy that no exercise uses" do
    Muscle.create!(key: "unused_muscle", name: "Unused")
    Equipment.create!(key: "unused_equipment", name: "Unused")

    result = taxonomy

    assert_not_includes result["muscles"].map { |m| m["key"] }, "unused_muscle"
    assert_not_includes result["equipment"].map { |e| e["key"] }, "unused_equipment"
  end

  test "returns categories in use" do
    assert_includes taxonomy["categories"], "strength"
    assert_includes taxonomy["categories"], "cardio"
  end

  test "orders difficulties easiest first, not alphabetically" do
    exercises(:bench_press).update!(difficulty: "intermediate")
    exercises(:squat).update!(difficulty: "advanced")

    assert_equal %w[beginner intermediate advanced], taxonomy["difficulties"]
  end

  test "an unknown difficulty still appears, after the known ones" do
    exercises(:bench_press).update!(difficulty: "elite")

    assert_equal "elite", taxonomy["difficulties"].last
  end

  test "muscles are ordered by name" do
    names = taxonomy["muscles"].map { |m| m["name"] }
    assert_equal names.sort, names
  end

  test "italian localizes muscle and equipment names but not keys" do
    result = taxonomy(headers: { "Accept-Language" => "it" })
    abs = result["muscles"].find { |m| m["key"] == "abs" }
    body_weight = result["equipment"].find { |e| e["key"] == "body_weight" }

    assert_equal "Addominali", abs["name"]
    assert_equal "abs", abs["key"], "the filter value must never change with locale"
    assert_equal "Corpo libero", body_weight["name"]
    assert_equal "body_weight", body_weight["key"]
  end

  test "italian muscles are still ordered by (translated) name" do
    # Not the same order as the english test above — sorting after
    # translating, not before, is the point being verified.
    names = taxonomy(headers: { "Accept-Language" => "it" })["muscles"].map { |m| m["name"] }
    assert_equal names.sort, names
  end

  test "italian filter keys still filter, proving the key was not accidentally translated" do
    result = taxonomy(headers: { "Accept-Language" => "it" })

    result["muscles"].each do |muscle|
      found = Catalog::ExerciseSearch.call(scope: Exercise.all, params: { muscle: muscle["key"] })
      assert_operator found.total_count, :>, 0, "muscle #{muscle['key']} filters to nothing under it"
    end
  end

  test "does not leak another coach's custom exercise categories" do
    other = User.create!(name: "Other", email: "other@example.com", role: "coach")
    Exercise.create!(
      name: "Secret", muscle_group: "Chest", is_custom: true, coach: other, category: "secret_category"
    )

    assert_not_includes taxonomy["categories"], "secret_category"
  end
end
