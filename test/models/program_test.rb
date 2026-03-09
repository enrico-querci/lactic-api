require "test_helper"

class ProgramTest < ActiveSupport::TestCase
  test "valid program" do
    program = programs(:strength_program)
    assert program.valid?
  end

  test "requires name" do
    program = Program.new(coach: users(:coach_john))
    assert_not program.valid?
    assert_includes program.errors[:name], "can't be blank"
  end

  test "requires coach" do
    program = Program.new(name: "Test")
    assert_not program.valid?
    assert_includes program.errors[:coach], "must exist"
  end

  test "has many weeks" do
    program = programs(:strength_program)
    assert_equal 2, program.weeks.count
  end
end
