module Review
  # The account App Review signs in with: a client who already has a coach, a
  # programme in progress and a few weeks of logged sessions, so every screen
  # of Lactic has something to show without anyone signing up.
  #
  # Reached only through Auth::ReviewAccess, behind a code that lives in the
  # REVIEW_ACCESS_CODE variable.
  #
  # Two properties keep this from becoming a way into real accounts:
  #
  # * Both users have an `.invalid` email address. That top-level domain can
  #   never be registered, so no real Google or Apple identity can carry it:
  #   `Auth::Authenticate` links a social sign-in to an existing user by email,
  #   and it can never reach these two.
  # * It owns nothing but its own data. A real coach or client is never
  #   touched, and nothing here reads or writes another user's records.
  #
  # The data is built from the live exercise catalog, so it never goes stale
  # against a provider re-sync, and it renews itself: an account nobody has
  # used for STALE_AFTER is rebuilt, which keeps the dates recent and also
  # restores it if the reviewer deleted the account from inside the app.
  class DemoAccount
    class SetupError < StandardError; end

    CLIENT_EMAIL = "client@review.lactic.invalid".freeze
    COACH_EMAIL = "coach@review.lactic.invalid".freeze
    PROGRAM_NAME = "Beginner Strength".freeze
    PROGRAM_WEEKS = 4
    STALE_AFTER = 10.days
    # Serialises concurrent rebuilds; any constant that is unique to this
    # feature will do.
    LOCK_KEY = 7_340_211

    # One entry per training day. Exercises come from these muscle groups in
    # the order listed, taking the next unused catalog exercise of each group,
    # so the same exercise never appears twice in one programme.
    WORKOUTS = [
      { name: "Upper Body", day: 1, groups: %w[Chest Back Shoulders Biceps Triceps] },
      { name: "Lower Body", day: 3, groups: %w[Quadriceps Hamstrings Glutes Calves] },
      { name: "Arms & Core", day: 5, groups: %w[Biceps Triceps Core Forearms] }
    ].freeze

    SETS = 3
    REPS = 8
    REST_SECONDS = 90
    WEEKLY_LOAD_STEP_KG = 2.5

    class << self
      # The demo client, rebuilt first if it is missing or has gone stale.
      def ensure!
        client = find_client
        return client if client && fresh?(client)

        ApplicationRecord.transaction do
          ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
          # Another request may have rebuilt it while this one waited.
          client = find_client
          client && fresh?(client) ? client : seed!
        end
      end

      def find_client
        User.client.find_by(email: CLIENT_EMAIL)
      end

      private

      def fresh?(client)
        return false unless client.coach_id && client.program_assignments.active.exists?

        last_session = client.workout_sessions.maximum(:started_at)
        last_session.present? && last_session > STALE_AFTER.ago
      end

      def seed!
        coach = demo_user(email: COACH_EMAIL, name: "Lactic Review Coach", role: :coach)
        client = demo_user(email: CLIENT_EMAIL, name: "Lactic Reviewer", role: :client)
        client.update!(coach: coach)

        # Everything below is rebuilt from scratch: the programme's
        # assignments and their sessions go with it.
        coach.programs.destroy_all
        client.workout_sessions.destroy_all

        program = build_program(coach)
        assignment = ProgramAssignment.create!(
          program: program, client: client, coach: coach, status: :active,
          start_date: Date.current.beginning_of_week - 2.weeks, notes: "Focus on form and keep two reps in reserve."
        )
        log_history(assignment)
        # The associations were loaded empty while clearing the old data.
        client.reload
      end

      def demo_user(email:, name:, role:)
        User.find_or_create_by!(email: email) do |user|
          user.name = name
          user.role = role
          user.provider = "review"
          user.provider_uid = "review-#{role}"
        end
      end

      def build_program(coach)
        program = coach.programs.create!(
          name: PROGRAM_NAME,
          description: "Four weeks of full-body strength training, three sessions a week."
        )
        picks = pick_exercises
        raise SetupError, "The exercise catalog has nothing to build the review programme from" if picks.all?(&:empty?)

        (1..PROGRAM_WEEKS).each do |position|
          week = program.weeks.create!(position: position)
          WORKOUTS.zip(picks).each do |spec, exercises|
            next if exercises.empty?

            build_workout(week, spec, exercises)
          end
        end
        program
      end

      def build_workout(week, spec, exercises)
        workout = week.workouts.create!(name: spec[:name], day: spec[:day])
        exercises.each_with_index do |exercise, index|
          workout.workout_exercises.create!(
            exercise: exercise, position: ("A".ord + index).chr, sets: SETS, reps: REPS,
            rest_seconds: REST_SECONDS, rir: 2, weight: suggested_weight(index),
            notes: index.zero? ? "Controlled tempo on the way down." : nil
          )
        end
      end

      # The next unused catalog exercise of each requested muscle group, in
      # the workout's own order. A group the catalog lacks is skipped.
      def pick_exercises
        pools = Exercise.catalog.active.assignable.order(:id).group_by(&:muscle_group)
        WORKOUTS.map { |spec| spec[:groups].filter_map { |group| pools[group]&.shift } }
      end

      def suggested_weight(index)
        20.0 + (index * 5)
      end

      # Every training day before today, week by week, so history is full,
      # the weights climb from one week to the next, and the current week is
      # part-way through.
      def log_history(assignment)
        assignment.program.weeks.includes(workouts: :workout_exercises).each do |week|
          week.workouts.each do |workout|
            date = assignment.start_date + ((week.position - 1) * 7) + (workout.day - 1)
            log_session(assignment, workout, week.position, date) if date < Date.current
          end
        end
      end

      def log_session(assignment, workout, week_position, date)
        started_at = date.in_time_zone.change(hour: 18)
        session = WorkoutSession.create!(
          client: assignment.client, workout: workout, program_assignment: assignment,
          started_at: started_at, completed_at: started_at + 65.minutes
        )
        load_added = (week_position - 1) * WEEKLY_LOAD_STEP_KG
        workout.workout_exercises.sort_by(&:position).each do |workout_exercise|
          log = session.exercise_logs.create!(workout_exercise: workout_exercise)
          workout_exercise.sets.times do |index|
            log.set_logs.create!(
              position: index + 1,
              weight_kg: workout_exercise.weight + load_added,
              reps: workout_exercise.reps - (index == workout_exercise.sets - 1 ? 1 : 0)
            )
          end
        end
      end
    end
  end
end
