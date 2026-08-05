require "test_helper"

module Catalog
  class NormalizeExerciseTest < ActiveSupport::TestCase
    # The fixture is an unmodified provider response captured on 2026-08-05.
    # Testing against it rather than a hand-written hash is the point: it is the
    # real contract, including the field casing the documentation gets wrong.
    def provider_records
      @provider_records ||= JSON.parse(
        file_fixture("workoutx/exercises_list_response.json").read
      ).fetch("data")
    end

    def first_record = provider_records.first

    def normalize(overrides = {})
      NormalizeExercise.call(first_record.merge(overrides))
    end

    # --- The real fixture ---------------------------------------------------

    test "normalizes a real provider record" do
      result = normalize

      assert result.valid?, result.errors.inspect
      assert_equal "0001", result.source_uid
      assert_equal "3/4 Sit-up", result.name
      assert_equal "strength", result.category
      assert_equal "beginner", result.difficulty
      assert_equal "isolation", result.mechanic
      assert_equal "push", result.force
    end

    test "keeps the source_uid as a zero-padded string" do
      assert_equal "0001", normalize.source_uid
      assert_instance_of String, normalize.source_uid
    end

    test "maps target to the primary muscle and bodyPart to its region" do
      primary = normalize.primary_muscle

      assert_equal "abs", primary.key
      assert_equal "Abs", primary.name
      assert_equal "Waist", primary.region
    end

    test "maps secondary muscles with no region" do
      secondary = normalize.secondary_muscles

      assert_equal %w[hip_flexors lower_back], secondary.map(&:key)
      assert_equal [ "Hip Flexors", "Lower Back" ], secondary.map(&:name)
      assert secondary.all? { |muscle| muscle.region.nil? }
    end

    test "instructions survive as an ordered array" do
      instructions = normalize.instructions

      assert_equal 5, instructions.size
      assert_equal "Lie flat on your back with your knees bent and feet flat on the ground.", instructions.first
      assert_equal "Repeat for the desired number of repetitions.", instructions.last
    end

    test "maps gifUrl onto a generic animation, never a gif-named field" do
      animation = normalize.animation

      assert_equal "https://api.workoutxapp.com/v1/gifs/0001.gif", animation.provider_url
      assert_equal "0001", animation.provider_media_uid
      assert_equal "image/gif", animation.mime_type
      assert_not NormalizeExercise::Result.members.include?(:gif_url)
    end

    test "every record in the fixture normalizes cleanly" do
      provider_records.each do |record|
        result = NormalizeExercise.call(record)
        assert result.valid?, "#{record['id']}: #{result.errors.inspect}"
        assert result.primary_muscle.present?
        assert result.animation.present?
      end
    end

    # --- Equipment ----------------------------------------------------------

    test "single equipment value" do
      assert_equal [ "body_weight" ], normalize.equipment.map(&:key)
    end

    test "splits a compound equipment string into separate items" do
      result = normalize("equipment" => "Dumbbell, Exercise Ball, Tennis Ball")

      assert_equal %w[dumbbell exercise_ball tennis_ball], result.equipment.map(&:key)
      assert_equal [ "Dumbbell", "Exercise Ball", "Tennis Ball" ], result.equipment.map(&:name)
    end

    test "strips a parenthetical qualifier so filters stay usable" do
      result = normalize("equipment" => "Dumbbell (used As Handles For Deeper Range)")

      assert_equal [ "dumbbell" ], result.equipment.map(&:key)
      assert_equal [ "Dumbbell" ], result.equipment.map(&:name)
    end

    test "deduplicates equipment that collapses onto the same key" do
      result = normalize("equipment" => "Dumbbell, Dumbbell (used As Handles)")

      assert_equal [ "dumbbell" ], result.equipment.map(&:key)
    end

    test "blank equipment yields no rows rather than an error" do
      result = normalize("equipment" => "")

      assert_empty result.equipment
      assert result.valid?
    end

    # --- Muscle edge cases --------------------------------------------------

    test "a secondary muscle equal to the primary is dropped" do
      result = normalize("secondaryMuscles" => [ "Abs", "Hip Flexors" ])

      assert_equal "abs", result.primary_muscle.key
      assert_equal [ "hip_flexors" ], result.secondary_muscles.map(&:key)
    end

    test "duplicate secondary muscles are collapsed" do
      result = normalize("secondaryMuscles" => [ "Hip Flexors", "Hip Flexors" ])

      assert_equal [ "hip_flexors" ], result.secondary_muscles.map(&:key)
    end

    test "missing secondary muscles is not an error" do
      result = normalize("secondaryMuscles" => nil)

      assert_empty result.secondary_muscles
      assert result.valid?
    end

    # --- Muscle synonyms ----------------------------------------------------
    #
    # The provider names the same muscle differently depending on whether it is
    # a target or a secondary muscle. Without collapsing them, `muscles` ends
    # up with two unrelated rows per pair and a coach filtering by Quads misses
    # every exercise where quads are secondary.

    test "a secondary synonym resolves to the primary vocabulary key" do
      result = normalize("secondaryMuscles" => [ "Quadriceps", "Chest", "Shoulders" ])

      assert_equal %w[quads pectorals delts], result.secondary_muscles.map(&:key)
    end

    test "every observed synonym maps onto a canonical key" do
      {
        "Chest" => "pectorals",
        "Upper Chest" => "pectorals",
        "Quadriceps" => "quads",
        "Shoulders" => "delts",
        "Rear Deltoids" => "delts",
        "Latissimus Dorsi" => "lats",
        "Trapezius" => "traps"
      }.each do |provider_value, canonical|
        assert_equal canonical, NormalizeExercise.muscle_key(provider_value), provider_value
      end
    end

    test "a synonym of the primary muscle is dropped as a duplicate" do
      # target is "Abs" in the fixture; use a record whose target is Pectorals.
      result = normalize("target" => "Pectorals", "secondaryMuscles" => [ "Chest", "Triceps" ])

      assert_equal "pectorals", result.primary_muscle.key
      assert_equal [ "triceps" ], result.secondary_muscles.map(&:key)
    end

    test "muscles with no primary equivalent keep their own identity" do
      result = normalize("secondaryMuscles" => [ "Core", "Obliques", "Hip Flexors", "Rhomboids", "Lower Back" ])

      assert_equal %w[core obliques hip_flexors rhomboids lower_back], result.secondary_muscles.map(&:key)
    end

    test "a target expressed as a synonym is also canonicalized" do
      assert_equal "quads", normalize("target" => "Quadriceps").primary_muscle.key
    end

    test "aliasing applies to muscles only, not to equipment" do
      # "Weighted" and friends must not be run through a muscle alias table.
      assert_equal "chest", NormalizeExercise.taxonomy_key("Chest")
      assert_equal "pectorals", NormalizeExercise.muscle_key("Chest")

      result = normalize("equipment" => "Body Weight")
      assert_equal [ "body_weight" ], result.equipment.map(&:key)
    end

    # --- Assignability ------------------------------------------------------

    test "strength work is assignable under a reps-only v1" do
      assert normalize("category" => "strength").assignable?
    end

    test "cardio, balance and flexibility work is not assignable" do
      %w[cardio balance flexibility].each do |category|
        assert_not normalize("category" => category).assignable?, category
      end
    end

    test "an unknown category is not assignable" do
      assert_not normalize("category" => "something new").assignable?
    end

    # --- Checksum -----------------------------------------------------------

    test "checksum is deterministic for identical content" do
      assert_equal normalize.content_checksum, normalize.content_checksum
    end

    test "checksum changes when translatable content changes" do
      baseline = normalize.content_checksum

      assert_not_equal baseline, normalize("name" => "Different").content_checksum
      assert_not_equal baseline, normalize("description" => "Different").content_checksum
      assert_not_equal baseline, normalize("instructions" => [ "Only one step." ]).content_checksum
    end

    test "checksum ignores taxonomy so retagging does not invalidate a translation" do
      baseline = normalize.content_checksum

      assert_equal baseline, normalize("equipment" => "Barbell").content_checksum
      assert_equal baseline, normalize("difficulty" => "advanced").content_checksum
      assert_equal baseline, normalize("popularityRank" => 999).content_checksum
    end

    test "checksum is insensitive to incidental whitespace" do
      assert_equal normalize.content_checksum, normalize("name" => "  3/4   Sit-up  ").content_checksum
    end

    # --- Malformed input ----------------------------------------------------

    test "reports every missing required field instead of raising" do
      result = NormalizeExercise.call({})

      assert_not result.valid?
      assert_includes result.errors, "missing id"
      assert_includes result.errors, "missing name"
      assert_includes result.errors, "missing target"
      assert_includes result.errors, "missing gifUrl"
    end

    test "reports missing instructions" do
      result = normalize("instructions" => [])

      assert_not result.valid?
      assert_includes result.errors, "missing instructions"
    end

    test "blank strings count as missing" do
      result = normalize("name" => "   ")

      assert_not result.valid?
      assert_includes result.errors, "missing name"
    end

    test "a target that is present but unusable is rejected" do
      result = normalize("target" => "()")

      assert_not result.valid?
      assert_nil result.primary_muscle
      assert_includes result.errors, "unusable target"
    end

    test "a valid record always carries a primary muscle" do
      result = normalize

      assert result.valid?
      assert_not_nil result.primary_muscle
    end

    test "a non-hash input is rejected rather than raising" do
      result = NormalizeExercise.call(nil)

      assert_not result.valid?
      assert_includes result.errors, "missing id"
    end

    test "an exercise missing a gif is invalid, since animation is a hard v1 requirement" do
      result = normalize("gifUrl" => nil)

      assert_not result.valid?
      assert_nil result.animation
      assert_includes result.errors, "missing gifUrl"
    end

    # --- Key helper ---------------------------------------------------------

    test "taxonomy_key normalizes provider wording" do
      assert_equal "ez_barbell", NormalizeExercise.taxonomy_key("Ez Barbell")
      assert_equal "body_weight", NormalizeExercise.taxonomy_key("Body Weight")
      assert_equal "upper_body_ergometer", NormalizeExercise.taxonomy_key("Upper Body Ergometer")
      assert_equal "cardiovascular_system", NormalizeExercise.taxonomy_key("Cardiovascular System")
    end

    test "taxonomy_key returns nil for empty input" do
      assert_nil NormalizeExercise.taxonomy_key("")
      assert_nil NormalizeExercise.taxonomy_key(nil)
      assert_nil NormalizeExercise.taxonomy_key("()")
    end
  end
end
