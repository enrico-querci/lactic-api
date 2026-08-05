require "test_helper"

module Catalog
  class ExerciseSearchTest < ActiveSupport::TestCase
    # `**params` rather than a positional hash: in Ruby 3.4 `search(muscle: "abs")`
    # binds as keywords, so a positional-hash signature raises unknown keyword.
    def search(**params)
      scope = params.delete(:scope) || Exercise.all
      ExerciseSearch.call(scope: scope, params: params)
    end

    def keys(result) = result.records.map(&:source_uid)

    # --- Search -------------------------------------------------------------

    test "finds a catalog exercise by its english name" do
      result = search(search: "Sit-up")

      assert_includes result.records, exercises(:provider_situp)
    end

    test "finds an exercise by its italian name while the response stays english" do
      # The whole point: an Italian-speaking coach types the Italian name and
      # the search still finds it, whatever locale the response renders in.
      result = search(search: "Corsa sul tapis")

      assert_includes result.records, exercises(:provider_treadmill)
    end

    test "finds a custom exercise, which has no translation rows at all" do
      result = search(search: "Coach Special")

      assert_includes result.records, exercises(:custom_exercise)
    end

    test "search is case insensitive" do
      assert_includes search(search: "sit-UP").records, exercises(:provider_situp)
    end

    test "search matches a description" do
      assert_includes search(search: "isolation exercise targeting").records, exercises(:provider_situp)
    end

    test "underscore is treated literally rather than as a wildcard" do
      exercises(:bench_press).update!(name: "Bench_Press")

      assert_includes search(search: "Bench_Press").records, exercises(:bench_press)
      assert_not_includes search(search: "Bench Press").records, exercises(:bench_press)
    end

    test "percent is treated literally" do
      exercises(:bench_press).update!(name: "100% Effort")

      assert_includes search(search: "100%").records, exercises(:bench_press)
      assert_empty search(search: "%%%%").records
    end

    test "a blank search does not filter" do
      assert_equal Exercise.count, search(search: "   ").total_count
    end

    # --- Muscle filters -----------------------------------------------------

    test "muscle filter matches either role" do
      result = search(muscle: "abs")
      assert_includes result.records, exercises(:provider_situp)

      secondary = search(muscle: "hip_flexors")
      assert_includes secondary.records, exercises(:provider_situp)
    end

    test "primary_muscle filter matches the target only" do
      assert_includes search(primary_muscle: "abs").records, exercises(:provider_situp)
      assert_not_includes search(primary_muscle: "hip_flexors").records, exercises(:provider_situp)
    end

    test "muscle filter matches the key case insensitively" do
      assert_includes search(muscle: "abs").records, exercises(:provider_situp)
      assert_includes search(muscle: "Abs").records, exercises(:provider_situp)
    end

    test "muscle filter takes a key, not a display name" do
      # "Hip Flexors" is the display name; hip_flexors is the key. Accepting
      # display names would make the filter depend on translated text.
      assert_empty search(muscle: "Hip Flexors").records
      assert_includes search(muscle: "hip_flexors").records, exercises(:provider_situp)
    end

    test "an exercise with several matching muscles appears once" do
      result = search(muscle: "abs")
      ids = result.records.map(&:id)

      assert_equal ids.uniq, ids
      assert_equal ids.size, result.total_count
    end

    # --- Other filters ------------------------------------------------------

    test "equipment filter" do
      assert_includes search(equipment: "body_weight").records, exercises(:provider_situp)
      assert_empty search(equipment: "barbell").records
    end

    test "category and difficulty filters" do
      assert_includes search(category: "strength").records, exercises(:provider_situp)
      assert_not_includes search(category: "cardio").records, exercises(:provider_situp)
      assert_includes search(difficulty: "beginner").records, exercises(:provider_situp)
    end

    test "custom filter separates coach content from the catalog" do
      assert_equal [ exercises(:custom_exercise) ], search(custom: "true").records
      assert_not_includes search(custom: "false").records, exercises(:custom_exercise)
    end

    test "legacy muscle_group filter still works for the deployed web client" do
      result = search(muscle_group: "Chest")

      assert_includes result.records, exercises(:bench_press)
      assert_not_includes result.records, exercises(:provider_situp)
    end

    test "filters compose" do
      result = search(category: "strength", equipment: "body_weight", primary_muscle: "abs")

      assert_equal [ exercises(:provider_situp) ], result.records
    end

    test "unknown filter values return nothing rather than everything" do
      assert_empty search(muscle: "no_such_muscle").records
      assert_empty search(equipment: "no_such_equipment").records
      assert_empty search(category: "no_such_category").records
    end

    # --- Pagination ---------------------------------------------------------

    test "defaults to the first page" do
      result = search

      assert_equal 1, result.page
      assert_equal ExerciseSearch::DEFAULT_PER_PAGE, result.per_page
    end

    test "paginates" do
      first = search(per_page: 2, page: 1)
      second = search(per_page: 2, page: 2)

      assert_equal 2, first.records.size
      assert_equal Exercise.count, first.total_count
      assert_empty(first.records.map(&:id) & second.records.map(&:id))
    end

    test "total_count reflects filters, not the page" do
      result = search(per_page: 1, custom: "true")

      assert_equal 1, result.records.size
      assert_equal 1, result.total_count
      assert_equal 1, result.total_pages
    end

    test "total_pages rounds up" do
      result = search(per_page: 2)

      assert_equal (Exercise.count / 2.0).ceil, result.total_pages
    end

    test "per_page is capped so a client cannot ask for the whole catalog" do
      assert_equal ExerciseSearch::MAX_PER_PAGE, search(per_page: 100_000).per_page
    end

    test "nonsense pagination falls back to sane values" do
      assert_equal 1, search(page: 0).page
      assert_equal 1, search(page: -5).page
      assert_equal ExerciseSearch::DEFAULT_PER_PAGE, search(per_page: 0).per_page
      assert_equal ExerciseSearch::DEFAULT_PER_PAGE, search(per_page: "abc").per_page
    end

    test "ordering is stable across pages" do
      one = search(per_page: 50).records.map(&:id)
      two = search(per_page: 50).records.map(&:id)

      assert_equal one, two
    end

    # --- Scope respected ----------------------------------------------------

    test "the given scope bounds the results" do
      result = search(scope: Exercise.selectable(users(:coach_john).id))

      assert_not_includes result.records, exercises(:provider_treadmill)
    end
  end
end
