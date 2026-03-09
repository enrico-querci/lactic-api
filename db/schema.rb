# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_09_163734) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "exercise_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "photo_url"
    t.datetime "updated_at", null: false
    t.bigint "workout_exercise_id", null: false
    t.bigint "workout_session_id", null: false
    t.index ["workout_exercise_id"], name: "index_exercise_logs_on_workout_exercise_id"
    t.index ["workout_session_id"], name: "index_exercise_logs_on_workout_session_id"
  end

  create_table "exercises", force: :cascade do |t|
    t.bigint "coach_id"
    t.datetime "created_at", null: false
    t.boolean "is_custom", default: false, null: false
    t.string "muscle_group", null: false
    t.string "name", null: false
    t.string "thumbnail_url"
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.index ["coach_id"], name: "index_exercises_on_coach_id"
    t.index ["muscle_group"], name: "index_exercises_on_muscle_group"
    t.index ["name"], name: "index_exercises_on_name"
  end

  create_table "program_assignments", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "coach_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "program_id", null: false
    t.date "start_date", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_program_assignments_on_client_id"
    t.index ["coach_id"], name: "index_program_assignments_on_coach_id"
    t.index ["program_id"], name: "index_program_assignments_on_program_id"
    t.index ["status"], name: "index_program_assignments_on_status"
  end

  create_table "programs", force: :cascade do |t|
    t.bigint "coach_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["coach_id"], name: "index_programs_on_coach_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "set_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exercise_log_id", null: false
    t.integer "position", null: false
    t.integer "reps", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight_kg", precision: 6, scale: 2, null: false
    t.index ["exercise_log_id", "position"], name: "index_set_logs_on_exercise_log_id_and_position", unique: true
    t.index ["exercise_log_id"], name: "index_set_logs_on_exercise_log_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.bigint "coach_id"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "provider"
    t.string "provider_uid"
    t.string "role", default: "client", null: false
    t.datetime "updated_at", null: false
    t.index ["coach_id"], name: "index_users_on_coach_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "provider_uid"], name: "index_users_on_provider_and_provider_uid", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "weeks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "program_id", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id", "position"], name: "index_weeks_on_program_id_and_position", unique: true
    t.index ["program_id"], name: "index_weeks_on_program_id"
  end

  create_table "workout_exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.text "notes"
    t.string "position", null: false
    t.integer "reps", null: false
    t.integer "rest_seconds"
    t.integer "rir"
    t.integer "sets", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 6, scale: 2
    t.bigint "workout_id", null: false
    t.index ["exercise_id"], name: "index_workout_exercises_on_exercise_id"
    t.index ["workout_id", "position"], name: "index_workout_exercises_on_workout_id_and_position", unique: true
    t.index ["workout_id"], name: "index_workout_exercises_on_workout_id"
  end

  create_table "workout_sessions", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "program_assignment_id", null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.bigint "workout_id", null: false
    t.index ["client_id"], name: "index_workout_sessions_on_client_id"
    t.index ["program_assignment_id"], name: "index_workout_sessions_on_program_assignment_id"
    t.index ["workout_id"], name: "index_workout_sessions_on_workout_id"
  end

  create_table "workout_templates", force: :cascade do |t|
    t.bigint "coach_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "source_workout_id", null: false
    t.datetime "updated_at", null: false
    t.index ["coach_id"], name: "index_workout_templates_on_coach_id"
    t.index ["source_workout_id"], name: "index_workout_templates_on_source_workout_id"
  end

  create_table "workouts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "week_id", null: false
    t.index ["week_id", "day"], name: "index_workouts_on_week_id_and_day"
    t.index ["week_id"], name: "index_workouts_on_week_id"
  end

  add_foreign_key "exercise_logs", "workout_exercises"
  add_foreign_key "exercise_logs", "workout_sessions"
  add_foreign_key "exercises", "users", column: "coach_id"
  add_foreign_key "program_assignments", "programs"
  add_foreign_key "program_assignments", "users", column: "client_id"
  add_foreign_key "program_assignments", "users", column: "coach_id"
  add_foreign_key "programs", "users", column: "coach_id"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "set_logs", "exercise_logs"
  add_foreign_key "users", "users", column: "coach_id"
  add_foreign_key "weeks", "programs"
  add_foreign_key "workout_exercises", "exercises"
  add_foreign_key "workout_exercises", "workouts"
  add_foreign_key "workout_sessions", "program_assignments"
  add_foreign_key "workout_sessions", "users", column: "client_id"
  add_foreign_key "workout_sessions", "workouts"
  add_foreign_key "workout_templates", "users", column: "coach_id"
  add_foreign_key "workout_templates", "workouts", column: "source_workout_id"
  add_foreign_key "workouts", "weeks"
end
