# The numbers and the to-do list behind the coach's Home, computed in one
# place so the web (and later the native Studio apps) fetch a single payload.
#
# "Needs attention" is the point of it: clients who stopped training, programs
# that are ending or over, clients with nothing assigned, and invitations that
# are about to lapse or already have. Everything is derived from what is
# already stored; nothing here writes.
class CoachDashboard
  INACTIVE_AFTER_DAYS = 7
  ENDING_WITHIN_DAYS = 7
  INVITATION_EXPIRING_WITHIN = 2.days
  ATTENTION_LIMIT = 10
  RECENT_LIMIT = 8

  # Most urgent first; ties are broken inside each kind by `days`.
  PRIORITY = %w[inactive program_ended program_ending no_program invitation_expired invitation_expiring].freeze

  def self.call(coach:, now: Time.current)
    new(coach, now).call
  end

  def initialize(coach, now)
    @coach = coach
    @now = now
    @today = now.to_date
  end

  def call
    items = attention_items
    {
      clients: { active: clients.size, slots_used: @coach.client_slots_used, limit: @coach.client_limit },
      sessions: { this_week: completed_between(week_start, nil), last_week: completed_between(week_start - 1.week, week_start) },
      pending_invitations: pending_invitations.count { |invitation| invitation.expires_at > @now },
      inactive_clients: items.count { |item| item[:kind] == "inactive" },
      attention: items.first(ATTENTION_LIMIT),
      attention_total: items.size,
      recent_activity: recent_activity
    }
  end

  private

  def clients
    @clients ||= @coach.clients.order(:name).to_a
  end

  def profiles_by_user_id
    @profiles_by_user_id ||= @coach.client_profiles.where(user_id: clients.map(&:id)).index_by(&:user_id)
  end

  # Completed workouts of this coach's assignments.
  def sessions
    WorkoutSession.joins(:program_assignment)
                  .where(program_assignments: { coach_id: @coach.id })
                  .where.not(completed_at: nil)
  end

  def week_start
    @now.beginning_of_week
  end

  def completed_between(from, to)
    scope = sessions.where(completed_at: from..)
    scope = scope.where(completed_at: ...to) if to
    scope.count
  end

  def active_assignments_by_client
    @active_assignments_by_client ||= ProgramAssignment.where(coach_id: @coach.id, status: "active", client_id: clients.map(&:id))
                                                       .includes(:program).group_by(&:client_id)
  end

  def weeks_by_program
    @weeks_by_program ||= Week.where(program_id: active_assignments_by_client.values.flatten.map(&:program_id).uniq)
                              .unscope(:order).group(:program_id).count
  end

  def last_completed_by_client
    @last_completed_by_client ||= sessions.group(:client_id).maximum(:completed_at)
  end

  def attention_items
    items = clients.flat_map { |client| client_items(client) } + invitation_items
    items.sort_by { |item| [ PRIORITY.index(item[:kind]), -item[:days].to_i ] }
  end

  def client_items(client)
    assignments = active_assignments_by_client[client.id]
    return [ item("no_program", client) ] if assignments.blank?

    [ inactive_item(client, assignments), program_item(client, assignments) ].compact
  end

  # Only for someone whose program has been running long enough to expect a
  # workout, counted from their last one, or from the start if there is none.
  def inactive_item(client, assignments)
    started = assignments.map(&:start_date).min
    return if started > @today - INACTIVE_AFTER_DAYS

    last = last_completed_by_client[client.id]
    days = last ? (@now - last).to_i / 1.day.to_i : (@today - started).to_i
    return if days < INACTIVE_AFTER_DAYS

    item("inactive", client, days: days, never_trained: last.nil?)
  end

  # The program that runs longest decides: someone on two programs is not
  # finished while one is still going.
  def program_item(client, assignments)
    ends = assignments.filter_map { |assignment| end_date(assignment) }.max
    return unless ends

    days_left = (ends - @today).to_i
    if days_left <= 0
      item("program_ended", client, days: -days_left)
    elsif days_left <= ENDING_WITHIN_DAYS
      item("program_ending", client, days: days_left)
    end
  end

  # The day after the last day of the program; nil for one with no weeks.
  def end_date(assignment)
    weeks = weeks_by_program[assignment.program_id].to_i
    assignment.start_date + (weeks * 7) if weeks.positive?
  end

  def invitation_items
    profiles = @coach.client_profiles.where(email: pending_invitations.map(&:email)).index_by(&:email)

    pending_invitations.filter_map do |invitation|
      kind = invitation_kind(invitation)
      next unless kind

      profile = profiles[invitation.email]
      { kind: kind, client_id: nil, profile_id: profile&.id, name: profile&.name || invitation.email, days: nil }
    end
  end

  def invitation_kind(invitation)
    return "invitation_expired" if invitation.expires_at <= @now

    "invitation_expiring" if invitation.expires_at <= @now + INVITATION_EXPIRING_WITHIN
  end

  def pending_invitations
    @pending_invitations ||= @coach.client_invitations.pending.to_a
  end

  def item(kind, client, days: nil, never_trained: false)
    { kind: kind, client_id: client.id, profile_id: profiles_by_user_id[client.id]&.id,
      name: client.name, days: days, never_trained: never_trained }
  end

  def recent_activity
    sessions.joins(:client).where(users: { coach_id: @coach.id })
            .includes(:client, :workout).order(completed_at: :desc).limit(RECENT_LIMIT)
            .map do |session|
      { id: session.id, client_id: session.client_id, client_name: session.client.name,
        workout_name: session.workout.name, completed_at: session.completed_at }
    end
  end
end
