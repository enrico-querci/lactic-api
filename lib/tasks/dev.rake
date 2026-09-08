# Development seed data for driving a real client through the whole flow.
#
# `db/seeds.rb` deliberately stays as-is: it runs in production through the
# Docker entrypoint's `bin/rails db:prepare`, so it is not the place for
# fixtures that only make sense on a laptop.
#
# This exists because the assign -> execute -> log path has never had data to
# run against outside the test suite. Both the production and development
# databases hold zero program assignments and zero workout sessions, so an iOS
# client pointed at a local server sees empty screens everywhere and a failure
# is ambiguous between client and server. `dev:seed` gives it something real.
#
# Idempotent: safe to re-run. Keyed on natural identifiers, never on ids.
namespace :dev do
  desc "Seed a coach, a client, a program, an assignment and one logged session (development/test only)"
  task seed: :environment do
    abort "dev:seed refuses to run in #{Rails.env}" unless Rails.env.development? || Rails.env.test?

    report = Catalog::TaxonomySeeder.call
    puts "taxonomy: #{report}"

    exercises = DevSeed.catalog_exercises
    puts "catalog:  #{exercises.size} exercises with en/it translations, muscles and equipment"

    coach   = DevSeed.coach
    alice   = DevSeed.client(email: "alice@example.com", name: "Alice Client", coach: coach)
    _bob    = DevSeed.client(email: "bob@example.com", name: "Bob Client", coach: coach)
    puts "users:    #{coach.email} (coach), alice@example.com + bob@example.com (clients)"

    program = DevSeed.program(coach: coach, exercises: exercises)
    puts "program:  #{program.name.inspect} — #{program.weeks.count} weeks, " \
         "#{program.weeks.sum { |w| w.workouts.count }} workouts"

    assignment = DevSeed.assignment(program: program, client: alice, coach: coach)
    puts "assign:   ##{assignment.id} to #{alice.email}, starting #{assignment.start_date} (#{assignment.status})"

    session = DevSeed.completed_session(assignment: assignment)
    puts "history:  session ##{session.id} completed with " \
         "#{session.exercise_logs.count} exercise logs / #{SetLog.where(exercise_log: session.exercise_logs).count} set logs"

    puts
    puts "Sign in with:  POST /api/v1/auth/dev_login  {\"email\":\"alice@example.com\"}"
  end

  desc "Remove everything dev:seed created, leaving the exercise catalog intact"
  task unseed: :environment do
    abort "dev:unseed refuses to run in #{Rails.env}" unless Rails.env.development? || Rails.env.test?

    program = Program.find_by(name: DevSeed::PROGRAM_NAME)
    program&.destroy!
    User.where(email: DevSeed::EMAILS).destroy_all
    puts "removed the dev program, its assignments and sessions, and #{DevSeed::EMAILS.size} users"
  end
end

# Namespaced here rather than in app/ so nothing in the deployed application
# can accidentally depend on seed helpers.
module DevSeed
  PROGRAM_NAME = "Upper/Lower Split (dev)".freeze
  COACH_EMAIL  = "john@example.com".freeze
  EMAILS       = [ COACH_EMAIL, "alice@example.com", "bob@example.com" ].freeze

  # A deliberately small catalog slice, but a *complete* one: every exercise
  # below has both locales, a primary and secondary muscle, equipment, and an
  # animation row. That is what makes Accept-Language, the taxonomy filters and
  # the animation endpoint testable locally without a provider key.
  CATALOG = [
    { uid: "dev-0001", group: "Chest",       en: "Barbell Bench Press", it: "Panca piana con bilanciere",
      primary: "pectorals", secondary: %w[triceps delts], equipment: %w[barbell],
      en_desc: "A compound press for the chest, front delts and triceps.",
      it_desc: "Spinta multiarticolare per petto, deltoidi anteriori e tricipiti.",
      en_steps: [ "Lie flat on the bench with feet planted.", "Lower the bar to mid-chest under control.", "Press back to lockout without flaring the elbows." ],
      it_steps: [ "Sdraiati sulla panca con i piedi ben appoggiati.", "Scendi con il bilanciere al centro del petto in controllo.", "Spingi fino a distendere le braccia senza aprire i gomiti." ] },
    { uid: "dev-0002", group: "Back",        en: "Bent-Over Barbell Row", it: "Rematore con bilanciere",
      primary: "upper_back", secondary: %w[biceps lats], equipment: %w[barbell],
      en_desc: "A horizontal pull for the mid back.", it_desc: "Trazione orizzontale per la parte centrale della schiena.",
      en_steps: [ "Hinge at the hips with a flat back.", "Row the bar to the navel.", "Lower under control." ],
      it_steps: [ "Piegati sulle anche mantenendo la schiena piatta.", "Tira il bilanciere verso l'ombelico.", "Scendi in controllo." ] },
    { uid: "dev-0003", group: "Shoulders",   en: "Dumbbell Lateral Raise", it: "Alzate laterali con manubri",
      primary: "delts", secondary: %w[traps], equipment: %w[dumbbell],
      en_desc: "An isolation raise for the side delts.", it_desc: "Esercizio di isolamento per i deltoidi laterali.",
      en_steps: [ "Stand with dumbbells at your sides.", "Raise to shoulder height with a slight bend.", "Lower slowly." ],
      it_steps: [ "In piedi con i manubri lungo i fianchi.", "Solleva fino all'altezza delle spalle con i gomiti morbidi.", "Scendi lentamente." ] },
    { uid: "dev-0004", group: "Quadriceps",  en: "Back Squat", it: "Squat con bilanciere",
      primary: "quads", secondary: %w[glutes hamstrings], equipment: %w[barbell],
      en_desc: "The primary compound lift for the legs.", it_desc: "Il principale esercizio multiarticolare per le gambe.",
      en_steps: [ "Unrack with the bar on your upper back.", "Squat to at least parallel.", "Drive up through mid-foot." ],
      it_steps: [ "Stacca il bilanciere appoggiato sul trapezio.", "Scendi almeno fino al parallelo.", "Risali spingendo con tutto il piede." ] },
    { uid: "dev-0005", group: "Hamstrings",  en: "Romanian Deadlift", it: "Stacco rumeno",
      primary: "hamstrings", secondary: %w[glutes spine], equipment: %w[barbell],
      en_desc: "A hip hinge loading the hamstrings.", it_desc: "Piegamento sulle anche che carica i femorali.",
      en_steps: [ "Hold the bar at the hips.", "Push the hips back keeping the bar close.", "Stand tall to finish." ],
      it_steps: [ "Tieni il bilanciere all'altezza delle anche.", "Porta indietro il bacino tenendo il bilanciere vicino.", "Risali completamente." ] },
    { uid: "dev-0006", group: "Biceps",      en: "Dumbbell Hammer Curl", it: "Curl a martello con manubri",
      primary: "biceps", secondary: %w[forearms], equipment: %w[dumbbell],
      en_desc: "A neutral-grip curl for the biceps and forearms.", it_desc: "Curl a presa neutra per bicipiti e avambracci.",
      en_steps: [ "Hold dumbbells with palms facing in.", "Curl without swinging.", "Lower under control." ],
      it_steps: [ "Impugna i manubri con i palmi rivolti verso l'interno.", "Fletti senza slanciare.", "Scendi in controllo." ] }
  ].freeze

  module_function

  def catalog_exercises
    CATALOG.map { |spec| upsert_exercise(spec) }
  end

  def upsert_exercise(spec)
    exercise = Exercise.find_or_initialize_by(source: "dev", source_uid: spec[:uid])
    exercise.assign_attributes(
      name: spec[:en], muscle_group: spec[:group], is_custom: false,
      category: "strength", difficulty: "beginner", mechanic: "compound", force: "push",
      active: true, assignable: true, prescription_type: "repetitions"
    )
    exercise.save!

    upsert_translation(exercise, "en", spec[:en], spec[:en_desc], spec[:en_steps])
    upsert_translation(exercise, "it", spec[:it], spec[:it_desc], spec[:it_steps])

    link_muscle(exercise, spec[:primary], "primary")
    spec[:secondary].each { |key| link_muscle(exercise, key, "secondary") }
    spec[:equipment].each { |key| link_equipment(exercise, key) }

    # A media row makes has_animation true so the client renders the animation
    # affordance. The URL is unreachable without a provider key, which is the
    # point: the app must handle 502 from the proxy as gracefully as 200.
    medium = exercise.exercise_media.find_or_initialize_by(kind: "animation", position: 1)
    medium.update!(provider_url: "https://example.invalid/dev/#{spec[:uid]}.gif", mime_type: "image/gif")

    exercise
  end

  def upsert_translation(exercise, locale, name, description, steps)
    row = exercise.exercise_translations.find_or_initialize_by(locale: locale)
    row.update!(name: name, description: description, instructions: steps, translation_source: "provider")
  end

  def link_muscle(exercise, key, role)
    muscle = Muscle.find_or_create_by!(key: key) { |m| m.name = key.tr("_", " ").split.map(&:capitalize).join(" ") }
    link = exercise.exercise_muscles.find_or_initialize_by(muscle: muscle)
    link.update!(role: role)
  end

  def link_equipment(exercise, key)
    item = Equipment.find_or_create_by!(key: key) { |e| e.name = key.tr("_", " ").split.map(&:capitalize).join(" ") }
    exercise.exercise_equipment.find_or_create_by!(equipment: item)
  end

  def coach
    User.find_or_create_by!(email: COACH_EMAIL) do |u|
      u.name = "John Coach"
      u.role = :coach
      u.provider = "dev"
      u.provider_uid = "dev_coach_1"
    end
  end

  def client(email:, name:, coach:)
    user = User.find_or_create_by!(email: email) do |u|
      u.name = name
      u.role = :client
      u.provider = "dev"
      u.provider_uid = "dev_#{email.split('@').first}"
    end
    user.update!(coach: coach) if user.coach_id != coach.id
    user
  end

  # Two weeks so the client app's "current week" logic has something to choose
  # between, and three workouts so "up next" has a real answer after one is
  # completed.
  def program(coach:, exercises:)
    program = coach.programs.find_or_create_by!(name: PROGRAM_NAME) do |p|
      p.description = "Two-week upper/lower split used for local development."
    end

    upper = %w[A B C].zip(exercises.values_at(0, 1, 2))
    lower = %w[A B].zip(exercises.values_at(3, 4))
    arms  = %w[A].zip(exercises.values_at(5))

    week1 = program.weeks.find_or_create_by!(position: 1)
    week2 = program.weeks.find_or_create_by!(position: 2)

    build_workout(week1, name: "Upper A", day: 1, rows: upper)
    build_workout(week1, name: "Lower A", day: 3, rows: lower)
    build_workout(week2, name: "Upper B", day: 1, rows: upper)
    build_workout(week2, name: "Arms",    day: 4, rows: arms)

    program.reload
  end

  def build_workout(week, name:, day:, rows:)
    workout = week.workouts.find_or_create_by!(name: name) { |w| w.day = day }
    rows.each_with_index do |(position, exercise), index|
      row = workout.workout_exercises.find_or_initialize_by(position: position)
      row.update!(
        exercise: exercise, sets: 3, reps: 8 + index,
        rest_seconds: 90, rir: 2, weight: 40.0 + (index * 10),
        notes: index.zero? ? "Keep the tempo controlled on the way down." : nil
      )
    end
    workout
  end

  # Backdated so the assignment is already under way and the client app has a
  # sensible "current week" rather than a programme starting in the future.
  def assignment(program:, client:, coach:)
    row = ProgramAssignment.find_or_initialize_by(program: program, client: client)
    row.update!(coach: coach, start_date: Date.current - 7, status: :active, notes: "Local development assignment.")
    row
  end

  # One completed session against week 1's first workout. This is what makes
  # history non-empty and gives the exercise-detail screen a "last time" to
  # show, which is otherwise unreachable on a fresh database.
  def completed_session(assignment:)
    workout = assignment.program.weeks.first.workouts.min_by(&:day)

    session = WorkoutSession.find_or_initialize_by(
      client: assignment.client, workout: workout, program_assignment: assignment
    )
    session.update!(
      started_at: 2.days.ago.change(hour: 18), completed_at: 2.days.ago.change(hour: 19, min: 5),
      notes: "Felt strong, bumped the bench up 2.5kg."
    )

    workout.workout_exercises.each do |workout_exercise|
      log = session.exercise_logs.find_or_initialize_by(workout_exercise: workout_exercise)
      log.update!(notes: workout_exercise.position == "A" ? "Last set was close to failure." : nil)

      workout_exercise.sets.times do |index|
        set = log.set_logs.find_or_initialize_by(position: index + 1)
        set.update!(weight_kg: workout_exercise.weight, reps: workout_exercise.reps - index)
      end
    end

    session.reload
  end
end
