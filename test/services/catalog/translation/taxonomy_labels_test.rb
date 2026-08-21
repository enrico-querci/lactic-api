require "test_helper"

module Catalog
  module Translation
    class TaxonomyLabelsTest < ActiveSupport::TestCase
      test "english returns the input verbatim" do
        assert_equal "Pectorals", TaxonomyLabels.muscle("Pectorals", "en")
        assert_equal "Barbell", TaxonomyLabels.equipment("Barbell", "en")
      end

      test "italian maps through the glossary" do
        assert_equal "Pettorali", TaxonomyLabels.muscle("Pectorals", "it")
        assert_equal "Bilanciere", TaxonomyLabels.equipment("Barbell", "it")
      end

      test "volume_sets passes the hash through unchanged in english" do
        counts = { "Chest" => 3, "Biceps" => 2 }

        assert_same counts, TaxonomyLabels.volume_sets(counts, "en")
      end

      test "volume_sets translates keys in italian" do
        result = TaxonomyLabels.volume_sets({ "Biceps" => 3 }, "it")

        assert_equal({ "Bicipiti" => 3 }, result)
      end

      test "volume_sets sums colliding english vocabularies onto one italian term" do
        # Chest (legacy seed) and Pectorals (provider import) both localize to
        # Pettorali. A naive transform_keys would silently drop one side.
        result = TaxonomyLabels.volume_sets({ "Chest" => 4, "Pectorals" => 5 }, "it")

        assert_equal({ "Pettorali" => 9 }, result)
      end

      test "volume_sets keeps unrelated muscles separate while summing the collision" do
        result = TaxonomyLabels.volume_sets({ "Chest" => 4, "Pectorals" => 5, "Biceps" => 3 }, "it")

        assert_equal({ "Pettorali" => 9, "Bicipiti" => 3 }, result)
      end
    end
  end
end
