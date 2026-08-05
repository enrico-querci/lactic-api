require "test_helper"

module Catalog
  class TaxonomySeederTest < ActiveSupport::TestCase
    test "seeds the published provider taxonomy" do
      TaxonomySeeder.call

      assert_equal 19, Muscle.where(key: seeded_muscle_keys).count
      assert_equal 30, Equipment.where(key: seeded_equipment_keys).count
    end

    test "seeds the closed primary-muscle vocabulary with regions" do
      TaxonomySeeder.call

      assert_equal "Waist", Muscle.find_by(key: "abs").region
      assert_equal "Upper Legs", Muscle.find_by(key: "quads").region
      assert_equal "Cardio", Muscle.find_by(key: "cardiovascular_system").region
    end

    test "is idempotent" do
      TaxonomySeeder.call
      counts = [ Muscle.count, Equipment.count ]

      TaxonomySeeder.call

      assert_equal counts, [ Muscle.count, Equipment.count ]
    end

    test "reports what it created" do
      report = TaxonomySeeder.call

      assert_operator report.muscles_created, :>, 0
      assert_operator report.equipment_created, :>, 0
      assert_equal 0, TaxonomySeeder.call.muscles_created
    end

    test "does not overwrite a region that live data already established" do
      Muscle.create!(key: "serratus_anterior", name: "Serratus Anterior", region: "Chest Wall")

      TaxonomySeeder.call

      assert_equal "Chest Wall", Muscle.find_by(key: "serratus_anterior").region
    end

    test "fills in a blank region" do
      muscles(:abs).update!(region: nil)

      TaxonomySeeder.call

      assert_equal "Waist", muscles(:abs).reload.region
    end

    test "never deletes a muscle the provider no longer publishes" do
      retired = Muscle.create!(key: "retired_muscle", name: "Retired", region: nil)

      TaxonomySeeder.call

      assert Muscle.exists?(retired.id)
    end

    test "leaves fixture-created taxonomy intact" do
      TaxonomySeeder.call

      assert Muscle.exists?(muscles(:hip_flexors).id)
      assert Equipment.exists?(equipment(:body_weight).id)
    end

    test "every key the seeder writes is a valid taxonomy key" do
      TaxonomySeeder.call

      Muscle.where(key: seeded_muscle_keys).find_each do |muscle|
        assert_equal muscle.key, NormalizeExercise.taxonomy_key(muscle.name),
          "seeded muscle #{muscle.key.inspect} does not match the normalizer's key for #{muscle.name.inspect}"
      end

      Equipment.where(key: seeded_equipment_keys).find_each do |item|
        assert_equal item.key, NormalizeExercise.taxonomy_key(item.name),
          "seeded equipment #{item.key.inspect} does not match the normalizer's key for #{item.name.inspect}"
      end
    end

    test "the fixture's own taxonomy values resolve to seeded keys" do
      TaxonomySeeder.call

      records = JSON.parse(file_fixture("workoutx/exercises_list_response.json").read).fetch("data")
      records.each do |record|
        result = NormalizeExercise.call(record)

        assert Muscle.exists?(key: result.primary_muscle.key),
          "primary muscle #{result.primary_muscle.key.inspect} is not seeded"
        result.equipment.each do |item|
          assert Equipment.exists?(key: item.key), "equipment #{item.key.inspect} is not seeded"
        end
      end
    end

    private

    def taxonomy_file
      @taxonomy_file ||= YAML.safe_load_file(TaxonomySeeder::DEFAULT_PATH)
    end

    def seeded_muscle_keys = taxonomy_file.fetch("muscles").map { |row| row.fetch("key") }
    def seeded_equipment_keys = taxonomy_file.fetch("equipment").map { |row| row.fetch("key") }
  end
end
