require "test_helper"

class EquipmentTest < ActiveSupport::TestCase
  test "valid equipment" do
    assert equipment(:body_weight).valid?
  end

  test "uses the singular table name" do
    assert_equal "equipment", Equipment.table_name
    assert_equal "exercise_equipment", ExerciseEquipment.table_name
  end

  test "requires a key and a name" do
    item = Equipment.new
    assert_not item.valid?
    assert_includes item.errors[:key], "can't be blank"
    assert_includes item.errors[:name], "can't be blank"
  end

  test "key is unique" do
    duplicate = Equipment.new(key: "barbell", name: "Barbell")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "reaches exercises through the join table" do
    assert_includes equipment(:body_weight).exercises, exercises(:provider_situp)
  end

  test "an exercise can carry several equipment rows" do
    exercise = exercises(:provider_situp)
    ExerciseEquipment.create!(exercise: exercise, equipment: equipment(:exercise_ball))
    assert_equal 2, exercise.reload.equipment.count
  end

  test "the same equipment cannot be linked twice to one exercise" do
    duplicate = ExerciseEquipment.new(exercise: exercises(:provider_situp), equipment: equipment(:body_weight))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:equipment_id], "has already been taken"
  end
end
