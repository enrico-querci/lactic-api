require "test_helper"

class MuscleTest < ActiveSupport::TestCase
  test "valid muscle" do
    assert muscles(:abs).valid?
  end

  test "requires a key and a name" do
    muscle = Muscle.new
    assert_not muscle.valid?
    assert_includes muscle.errors[:key], "can't be blank"
    assert_includes muscle.errors[:name], "can't be blank"
  end

  test "key is unique" do
    duplicate = Muscle.new(key: "abs", name: "Abdominals")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "database rejects a duplicate key even without validations" do
    duplicate = Muscle.new(key: "abs", name: "Abdominals")
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  test "region groups muscles the way the provider groups body parts" do
    assert_equal "Waist", muscles(:abs).region
    assert_includes Muscle.in_region("Waist"), muscles(:abs)
    assert_not_includes Muscle.in_region("Waist"), muscles(:pectorals)
  end

  test "a secondary-only muscle has no region" do
    # `bodyPart` describes the exercise's target, so a muscle that only ever
    # appears in secondaryMuscles has nothing to derive a region from.
    assert_nil muscles(:hip_flexors).region
    assert_nil muscles(:lower_back).region
  end

  test "reaches exercises through the join table" do
    assert_includes muscles(:abs).exercises, exercises(:provider_situp)
  end
end
