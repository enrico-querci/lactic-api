require "test_helper"

class CoachDashboardTest < ActiveSupport::TestCase
  # A Friday, so this week started on Monday the 16th.
  NOW = Time.zone.parse("2026-03-20 12:00:00")

  setup do
    @coach = users(:coach_john)
    @alice = users(:client_alice)
    @bob = users(:client_bob)
    @program = programs(:strength_program) # two weeks
    @workout = workouts(:chest_day)
  end

  def dashboard(now: NOW)
    CoachDashboard.call(coach: @coach, now: now)
  end

  def attention(kind: nil, name: nil)
    dashboard[:attention].select { |item| (kind.nil? || item[:kind] == kind) && (name.nil? || item[:name] == name) }
  end

  def complete_session(client, at, assignment: nil)
    assignment ||= ProgramAssignment.find_by!(client: client, coach: @coach)
    WorkoutSession.create!(client: client, workout: @workout, program_assignment: assignment, started_at: at - 1.hour, completed_at: at)
  end

  def assign(client, start_date, program: @program, status: "active")
    ProgramAssignment.create!(client: client, coach: @coach, program: program, start_date: start_date, status: status)
  end

  test "counts clients and reports the plan" do
    result = dashboard
    assert_equal 2, result[:clients][:active]
    assert_equal @coach.client_slots_used, result[:clients][:slots_used]
    assert_equal @coach.client_limit, result[:clients][:limit]
  end

  test "counts completed workouts this week and last week" do
    assignment = ProgramAssignment.find_by!(client: @alice, coach: @coach)
    complete_session(@alice, Time.zone.parse("2026-03-16 08:00"), assignment: assignment) # Monday: this week
    complete_session(@alice, Time.zone.parse("2026-03-19 08:00"), assignment: assignment)
    complete_session(@alice, Time.zone.parse("2026-03-15 20:00"), assignment: assignment) # Sunday: last week
    complete_session(@alice, Time.zone.parse("2026-03-09 08:00"), assignment: assignment) # Monday: last week
    complete_session(@alice, Time.zone.parse("2026-03-08 20:00"), assignment: assignment) # before: neither

    assert_equal({ this_week: 2, last_week: 2 }, dashboard[:sessions])
  end

  test "a started but unfinished workout is not counted" do
    assignment = ProgramAssignment.find_by!(client: @alice, coach: @coach)
    WorkoutSession.create!(client: @alice, workout: @workout, program_assignment: assignment, started_at: NOW - 1.hour)
    assert_equal 0, dashboard[:sessions][:this_week]
  end

  test "another coach's workouts are not counted" do
    other = User.create!(name: "Other Coach", email: "other-dash@example.com", role: :coach)
    stranger = User.create!(name: "Stranger", email: "stranger-dash@example.com", role: :client, coach: other)
    foreign_program = other.programs.create!(name: "Theirs")
    foreign_workout = foreign_program.weeks.create!(position: 1).workouts.create!(name: "W", day: 1)
    assignment = ProgramAssignment.create!(client: stranger, coach: other, program: foreign_program, start_date: NOW.to_date - 3)
    WorkoutSession.create!(client: stranger, workout: foreign_workout, program_assignment: assignment,
                           started_at: NOW - 2.hours, completed_at: NOW - 1.hour)

    assert_equal 0, dashboard[:sessions][:this_week]
    assert_empty dashboard[:recent_activity].select { |a| a[:client_name] == "Stranger" }
  end

  # --- needs attention ---

  test "a client who stopped training is flagged with the days since their last workout" do
    complete_session(@alice, Time.zone.parse("2026-03-10 12:00"))
    item = attention(kind: "inactive", name: "Alice Client").first

    assert_equal 10, item[:days]
    assert_equal false, item[:never_trained]
    assert_equal @alice.id, item[:client_id]
    assert_equal client_profiles(:alice_profile).id, item[:profile_id]
    assert_equal 1, dashboard[:inactive_clients]
  end

  test "someone who trained within a week is not inactive, and the threshold is seven days" do
    # Alice's program is over; keep the focus on the inactive kind only.
    complete_session(@alice, NOW - 6.days - 23.hours)
    assert_empty attention(kind: "inactive", name: "Alice Client")

    WorkoutSession.destroy_all
    complete_session(@alice, NOW - 7.days)
    assert_equal 7, attention(kind: "inactive", name: "Alice Client").first[:days]
  end

  test "a client who never trained is flagged once the program has run a week" do
    assignment = assign(@bob, NOW.to_date - 9, program: @program)
    item = attention(kind: "inactive", name: "Bob Client").first
    assert_equal 9, item[:days]
    assert_equal true, item[:never_trained]
    assignment.destroy!
  end

  test "someone whose program started this week is not yet inactive" do
    assign(@bob, NOW.to_date - 3)
    assert_empty attention(kind: "inactive", name: "Bob Client")
  end

  test "a client with no active program is flagged" do
    assert_equal [ "no_program" ], attention(name: "Bob Client").map { |item| item[:kind] }
  end

  test "a paused assignment counts as no program" do
    ProgramAssignment.find_by!(client: @alice, coach: @coach).update!(status: "paused")
    assert_equal [ "no_program" ], attention(name: "Alice Client").map { |item| item[:kind] }
  end

  test "a program that is over is flagged with how long ago" do
    # Two weeks from 2026-03-01 ends on the 15th; the 20th is five days later.
    item = attention(kind: "program_ended", name: "Alice Client").first
    assert_equal 5, item[:days]
  end

  test "a program ending within a week is flagged with the days left" do
    ProgramAssignment.find_by!(client: @alice, coach: @coach).update!(start_date: NOW.to_date - 10)
    complete_session(@alice, NOW - 1.day)

    item = attention(kind: "program_ending", name: "Alice Client").first
    assert_equal 4, item[:days]
    assert_empty attention(kind: "program_ended", name: "Alice Client")
  end

  test "a program with plenty of time left is not flagged" do
    ProgramAssignment.find_by!(client: @alice, coach: @coach).update!(start_date: NOW.to_date - 2)
    complete_session(@alice, NOW - 1.day)
    assert_empty attention(name: "Alice Client")
  end

  test "someone on two programs is not finished while one is still running" do
    long_program = @coach.programs.create!(name: "Long")
    4.times { |index| long_program.weeks.create!(position: index + 1) }
    assign(@alice, NOW.to_date - 5, program: long_program)
    complete_session(@alice, NOW - 1.day, assignment: ProgramAssignment.find_by!(client: @alice, program: long_program))

    assert_empty attention(kind: "program_ended", name: "Alice Client")
  end

  test "a program with no weeks never counts as ended" do
    empty = @coach.programs.create!(name: "Empty")
    ProgramAssignment.find_by!(client: @alice, coach: @coach).update!(program: empty)
    assert_empty attention(kind: "program_ended", name: "Alice Client")
  end

  test "an invitation about to lapse, and one that has, are flagged; a fresh one is not" do
    ClientInvitation.create!(coach: @coach, email: "soon@example.com", expires_at: NOW + 1.day)
    ClientInvitation.create!(coach: @coach, email: "lapsed@example.com", expires_at: NOW - 1.hour)
    ClientInvitation.create!(coach: @coach, email: "fresh@example.com", expires_at: NOW + 5.days)

    kinds = dashboard[:attention].select { |item| item[:client_id].nil? }.to_h { |item| [ item[:name], item[:kind] ] }
    assert_equal({ "soon@example.com" => "invitation_expiring", "lapsed@example.com" => "invitation_expired" }, kinds)
    assert_equal 2, dashboard[:pending_invitations] # soon and fresh can still be accepted; lapsed cannot
  end

  test "an invitation shows the name of the profile prepared for that email" do
    ClientInvitation.create!(coach: @coach, email: "carla@example.com", expires_at: NOW + 1.day)
    item = attention(kind: "invitation_expiring").first

    assert_equal "Carla Prepared", item[:name]
    assert_equal client_profiles(:carla_prepared).id, item[:profile_id]
  end

  test "a revoked invitation is not flagged" do
    ClientInvitation.create!(coach: @coach, email: "gone@example.com", expires_at: NOW - 1.day).revoke!
    assert_empty dashboard[:attention].select { |item| item[:name] == "gone@example.com" }
  end

  test "the list is ordered by urgency and capped, with the full count reported" do
    12.times do |index|
      ClientInvitation.create!(coach: @coach, email: "late#{index}@example.com", expires_at: NOW - 1.day)
    end

    result = dashboard
    assert_equal CoachDashboard::ATTENTION_LIMIT, result[:attention].size
    assert_operator result[:attention_total], :>, CoachDashboard::ATTENTION_LIMIT
    assert_equal "inactive", result[:attention].first[:kind]
    kinds = result[:attention].map { |item| item[:kind] }
    assert_equal kinds, kinds.sort_by { |kind| CoachDashboard::PRIORITY.index(kind) }
  end

  test "a removed client is not part of the summary" do
    @bob.update!(coach: nil)
    assert_equal 1, dashboard[:clients][:active]
    assert_empty attention(name: "Bob Client")
  end

  # --- recent activity ---

  test "recent activity lists the latest completed workouts, newest first" do
    complete_session(@alice, Time.zone.parse("2026-03-18 09:00"))
    complete_session(@alice, Time.zone.parse("2026-03-19 09:00"))

    activity = dashboard[:recent_activity]
    assert_equal [ "2026-03-19", "2026-03-18" ], activity.first(2).map { |entry| entry[:completed_at].to_date.to_s }
    assert_equal [ "Alice Client", @workout.name ], [ activity.first[:client_name], activity.first[:workout_name] ]
  end

  test "recent activity is capped" do
    (CoachDashboard::RECENT_LIMIT + 3).times { |index| complete_session(@alice, NOW - index.hours) }
    assert_equal CoachDashboard::RECENT_LIMIT, dashboard[:recent_activity].size
  end

  test "recent activity leaves out a client who has been removed" do
    assign(@bob, NOW.to_date - 2)
    complete_session(@bob, NOW - 1.hour)
    @bob.update!(coach: nil)
    assert_empty dashboard[:recent_activity].select { |entry| entry[:client_name] == "Bob Client" }
  end

  test "an empty coach gets zeros and empty lists" do
    other = User.create!(name: "New Coach", email: "new-coach-dash@example.com", role: :coach)
    result = CoachDashboard.call(coach: other, now: NOW)

    assert_equal 0, result[:clients][:active]
    assert_equal({ this_week: 0, last_week: 0 }, result[:sessions])
    assert_equal [], result[:attention]
    assert_equal [], result[:recent_activity]
  end
end
