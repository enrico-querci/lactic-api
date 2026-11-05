require "test_helper"

class Review::DemoAccountTest < ActiveSupport::TestCase
  test "builds a client with a coach, an active programme and a history of completed sessions" do
    client = Review::DemoAccount.ensure!

    assert client.client?
    assert_equal Review::DemoAccount::CLIENT_EMAIL, client.email
    assert_equal Review::DemoAccount::COACH_EMAIL, client.coach.email

    assignment = client.program_assignments.sole
    assert assignment.active?
    assert_equal Review::DemoAccount::PROGRAM_WEEKS, assignment.program.weeks.count

    sessions = client.workout_sessions
    assert_operator sessions.count, :>=, 6
    assert(sessions.all? { |session| session.completed_at.present? && session.completed_at < Time.current })
    assert(sessions.all? { |session| session.exercise_logs.any? && session.exercise_logs.all? { |log| log.set_logs.any? } })
  end

  test "both users carry an address no real sign-in can have" do
    client = Review::DemoAccount.ensure!

    assert client.email.end_with?(".invalid")
    assert client.coach.email.end_with?(".invalid")
  end

  test "builds the programme from the catalog and never from a coach's custom exercises" do
    Review::DemoAccount.ensure!

    used = WorkoutExercise.where(workout: Workout.where(week: Program.find_by!(name: Review::DemoAccount::PROGRAM_NAME).weeks)).map(&:exercise)

    assert_includes used, exercises(:bench_press)
    assert_includes used, exercises(:squat)
    assert_not_includes used, exercises(:custom_exercise)
    assert_equal used.uniq, used.uniq & Exercise.catalog
  end

  test "the weights climb from one week to the next" do
    client = Review::DemoAccount.ensure!

    by_week = client.workout_sessions.includes(workout: :week, exercise_logs: :set_logs).group_by { |s| s.workout.week.position }
    first_week = by_week.fetch(1).flat_map { |s| s.exercise_logs.flat_map { |l| l.set_logs.map(&:weight_kg) } }.max
    second_week = by_week.fetch(2).flat_map { |s| s.exercise_logs.flat_map { |l| l.set_logs.map(&:weight_kg) } }.max

    assert_operator second_week, :>, first_week
  end

  test "calling it again changes nothing while the account is in use" do
    first = Review::DemoAccount.ensure!

    assert_no_difference [ "User.count", "Program.count", "ProgramAssignment.count", "WorkoutSession.count", "SetLog.count" ] do
      assert_equal first, Review::DemoAccount.ensure!
    end
  end

  test "rebuilds an account nobody has used for a while, keeping the same user" do
    first = Review::DemoAccount.ensure!
    first.workout_sessions.update_all(started_at: 30.days.ago, completed_at: 30.days.ago)

    again = Review::DemoAccount.ensure!

    assert_equal first, again
    assert_operator again.workout_sessions.maximum(:started_at), :>, 10.days.ago
    assert_equal 1, again.program_assignments.count
    assert_equal 1, Program.where(name: Review::DemoAccount::PROGRAM_NAME).count
  end

  test "rebuilds the account if the reviewer deleted it" do
    Review::DemoAccount.ensure!.destroy!
    assert_nil Review::DemoAccount.find_client

    client = Review::DemoAccount.ensure!

    assert client.workout_sessions.any?
  end

  test "never touches anyone else's data" do
    alice = users(:client_alice)
    before = [ alice.reload.updated_at, alice.program_assignments.count, alice.workout_sessions.count, users(:coach_john).programs.count ]

    Review::DemoAccount.ensure!
    Review::DemoAccount.ensure!.workout_sessions.update_all(started_at: 30.days.ago)
    Review::DemoAccount.ensure!

    assert_equal before, [ alice.reload.updated_at, alice.program_assignments.count, alice.workout_sessions.count, users(:coach_john).programs.count ]
  end

  test "fills out the workouts when the catalog has more to offer" do
    { "Back" => "Row", "Shoulders" => "Press", "Triceps" => "Pushdown", "Hamstrings" => "Curl", "Glutes" => "Bridge" }.each do |group, name|
      Exercise.create!(name: name, muscle_group: group, is_custom: false)
    end

    Review::DemoAccount.ensure!
    upper = Workout.joins(:week).where(name: "Upper Body", weeks: { position: 1 }).sole

    assert_equal %w[A B C D E], upper.workout_exercises.order(:position).map(&:position)
    assert_equal upper.workout_exercises.map(&:exercise_id).uniq.size, upper.workout_exercises.size
  end

  test "raises when the catalog has nothing to build from" do
    Exercise.update_all(active: false)

    assert_raises(Review::DemoAccount::SetupError) { Review::DemoAccount.ensure! }
  end
end
