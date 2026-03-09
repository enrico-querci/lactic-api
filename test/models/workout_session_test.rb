require "test_helper"

class WorkoutSessionTest < ActiveSupport::TestCase
  test "valid workout session" do
    session = workout_sessions(:alice_chest_session)
    assert session.valid?
  end

  test "requires client" do
    session = WorkoutSession.new(workout: workouts(:chest_day),
                                 program_assignment: program_assignments(:alice_strength))
    assert_not session.valid?
    assert_includes session.errors[:client], "must exist"
  end

  test "client must have client role" do
    session = WorkoutSession.new(client: users(:coach_john),
                                 workout: workouts(:chest_day),
                                 program_assignment: program_assignments(:alice_strength))
    assert_not session.valid?
    assert_includes session.errors[:client], "must have the client role"
  end

  test "has many exercise logs" do
    session = workout_sessions(:alice_chest_session)
    assert_equal 1, session.exercise_logs.count
  end
end
