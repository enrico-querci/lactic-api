require "test_helper"

class ProgramAssignmentTest < ActiveSupport::TestCase
  test "valid program assignment" do
    assignment = program_assignments(:alice_strength)
    assert assignment.valid?
    assert assignment.active?
  end

  test "requires start_date" do
    assignment = ProgramAssignment.new(program: programs(:strength_program),
                                       client: users(:client_alice),
                                       coach: users(:coach_john))
    assert_not assignment.valid?
    assert_includes assignment.errors[:start_date], "can't be blank"
  end

  test "client must have client role" do
    assignment = ProgramAssignment.new(program: programs(:strength_program),
                                       client: users(:coach_john),
                                       coach: users(:coach_john),
                                       start_date: Date.today)
    assert_not assignment.valid?
    assert_includes assignment.errors[:client], "must have the client role"
  end

  test "coach must have coach role" do
    assignment = ProgramAssignment.new(program: programs(:strength_program),
                                       client: users(:client_alice),
                                       coach: users(:client_alice),
                                       start_date: Date.today)
    assert_not assignment.valid?
    assert_includes assignment.errors[:coach], "must have the coach role"
  end

  test "status enum" do
    assignment = program_assignments(:alice_strength)
    assert assignment.active?

    assignment.status = :completed
    assert assignment.completed?

    assignment.status = :paused
    assert assignment.paused?
  end
end
