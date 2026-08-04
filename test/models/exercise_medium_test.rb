require "test_helper"

class ExerciseMediumTest < ActiveSupport::TestCase
  test "valid animation" do
    medium = exercise_media(:situp_animation)
    assert medium.valid?
    assert medium.animation?
    assert_equal "image/gif", medium.mime_type
  end

  test "uses the generic kind rather than a gif-specific field" do
    assert_includes ExerciseMedium.column_names, "kind"
    assert_not_includes ExerciseMedium.column_names, "gif_url"
  end

  test "rejects an unknown kind" do
    medium = ExerciseMedium.new(exercise: exercises(:bench_press), kind: "hologram")
    assert_not medium.valid?
    assert_includes medium.errors[:kind], "is not included in the list"
  end

  test "database rejects an unknown kind even without validations" do
    medium = ExerciseMedium.new(exercise: exercises(:bench_press), kind: "hologram", position: 1)
    assert_raises(ActiveRecord::StatementInvalid) { medium.save(validate: false) }
  end

  test "position must be positive" do
    medium = ExerciseMedium.new(exercise: exercises(:bench_press), kind: "animation", position: 0)
    assert_not medium.valid?
    assert_includes medium.errors[:position], "must be greater than 0"
  end

  test "position is unique per exercise and kind" do
    duplicate = ExerciseMedium.new(exercise: exercises(:provider_situp), kind: "animation", position: 1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position], "has already been taken"
  end

  test "the same position is allowed for a different kind" do
    image = ExerciseMedium.new(exercise: exercises(:provider_situp), kind: "image", position: 1)
    assert image.valid?
  end

  test "animation returns the lowest positioned animation" do
    exercise = exercises(:provider_situp)
    ExerciseMedium.create!(exercise: exercise, kind: "animation", position: 2)
    assert_equal exercise_media(:situp_animation), exercise.reload.animation
  end

  test "exercise without media has no animation" do
    assert_nil exercises(:bench_press).animation
  end

  test "destroying an exercise destroys its media" do
    exercise = exercises(:provider_situp)
    assert_difference "ExerciseMedium.count", -1 do
      exercise.destroy!
    end
  end
end
