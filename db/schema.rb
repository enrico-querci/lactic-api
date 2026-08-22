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

ActiveRecord::Schema[8.1].define(version: 2026_08_22_090100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "catalog_sync_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.integer "deactivated_count", default: 0, null: false
    t.text "error_summary"
    t.integer "fetched_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "rejected_count", default: 0, null: false
    t.string "source", null: false
    t.datetime "started_at", null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["source", "started_at"], name: "index_catalog_sync_runs_on_source_and_started_at"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying::text, 'succeeded'::character varying::text, 'failed'::character varying::text])", name: "catalog_sync_runs_status"
  end

  create_table "client_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "coach_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "sent_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["coach_id", "email"], name: "index_pending_client_invitations_on_coach_and_email", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["coach_id"], name: "index_client_invitations_on_coach_id"
    t.index ["token_digest"], name: "index_client_invitations_on_token_digest", unique: true
  end

  create_table "coach_subscriptions", force: :cascade do |t|
    t.boolean "auto_renew", default: true, null: false
    t.datetime "billing_issue_at"
    t.datetime "created_at", null: false
    t.string "entitlement_id"
    t.string "environment", default: "PRODUCTION", null: false
    t.datetime "expires_at"
    t.string "plan_key", null: false
    t.string "product_id"
    t.string "revenuecat_app_user_id"
    t.string "store"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_coach_subscriptions_on_user_id", unique: true
    t.check_constraint "environment::text = ANY (ARRAY['PRODUCTION'::character varying, 'SANDBOX'::character varying]::text[])", name: "coach_subscriptions_environment"
    t.check_constraint "plan_key::text = ANY (ARRAY['free'::character varying, 'pro'::character varying, 'pro_plus'::character varying, 'unlimited'::character varying, 'founding'::character varying]::text[])", name: "coach_subscriptions_plan_key"
  end

  create_table "equipment", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_equipment_on_key", unique: true
  end

  create_table "exercise_equipment", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "equipment_id", null: false
    t.bigint "exercise_id", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_exercise_equipment_on_equipment_id"
    t.index ["exercise_id", "equipment_id"], name: "index_exercise_equipment_on_exercise_id_and_equipment_id", unique: true
    t.index ["exercise_id"], name: "index_exercise_equipment_on_exercise_id"
  end

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

  create_table "exercise_media", force: :cascade do |t|
    t.string "attribution"
    t.bigint "byte_size"
    t.string "checksum"
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.integer "height"
    t.string "kind", default: "animation", null: false
    t.string "license"
    t.string "mime_type"
    t.integer "position", default: 1, null: false
    t.string "provider_media_uid"
    t.string "provider_url"
    t.datetime "updated_at", null: false
    t.integer "width"
    t.index ["exercise_id", "kind", "position"], name: "index_exercise_media_on_exercise_id_and_kind_and_position", unique: true
    t.index ["exercise_id"], name: "index_exercise_media_on_exercise_id"
    t.check_constraint "\"position\" > 0", name: "exercise_media_position_positive"
    t.check_constraint "kind::text = ANY (ARRAY['animation'::character varying::text, 'image'::character varying::text, 'video'::character varying::text])", name: "exercise_media_kind"
  end

  create_table "exercise_muscles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.bigint "muscle_id", null: false
    t.string "role", default: "primary", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_id", "muscle_id"], name: "index_exercise_muscles_on_exercise_id_and_muscle_id", unique: true
    t.index ["exercise_id", "role"], name: "index_exercise_muscles_on_exercise_id_and_role"
    t.index ["exercise_id"], name: "index_exercise_muscles_on_exercise_id"
    t.index ["exercise_id"], name: "index_exercise_muscles_on_single_primary", unique: true, where: "((role)::text = 'primary'::text)"
    t.index ["muscle_id"], name: "index_exercise_muscles_on_muscle_id"
    t.check_constraint "role::text = ANY (ARRAY['primary'::character varying::text, 'secondary'::character varying::text])", name: "exercise_muscles_role"
  end

  create_table "exercise_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "exercise_id", null: false
    t.jsonb "instructions", default: [], null: false
    t.string "locale", null: false
    t.string "name", null: false
    t.datetime "reviewed_at"
    t.string "source_checksum"
    t.string "translation_source", default: "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_id", "locale"], name: "index_exercise_translations_on_exercise_id_and_locale", unique: true
    t.index ["exercise_id"], name: "index_exercise_translations_on_exercise_id"
    t.index ["name"], name: "index_exercise_translations_on_name"
    t.check_constraint "translation_source::text = ANY (ARRAY['provider'::character varying::text, 'machine'::character varying::text, 'human'::character varying::text])", name: "exercise_translations_source"
  end

  create_table "exercises", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "assignable", default: true, null: false
    t.string "category"
    t.bigint "coach_id"
    t.string "content_checksum"
    t.datetime "created_at", null: false
    t.string "difficulty"
    t.string "force"
    t.boolean "is_custom", default: false, null: false
    t.datetime "last_synced_at"
    t.string "mechanic"
    t.string "muscle_group", null: false
    t.string "name", null: false
    t.string "prescription_type", default: "repetitions", null: false
    t.string "source"
    t.string "source_uid"
    t.string "thumbnail_url"
    t.datetime "updated_at", null: false
    t.string "video_url"
    t.index ["active", "assignable"], name: "index_exercises_on_active_and_assignable"
    t.index ["coach_id"], name: "index_exercises_on_coach_id"
    t.index ["muscle_group"], name: "index_exercises_on_muscle_group"
    t.index ["name"], name: "index_exercises_on_name"
    t.index ["source", "source_uid"], name: "index_exercises_on_provider_identity", unique: true, where: "((source IS NOT NULL) AND (source_uid IS NOT NULL))"
    t.check_constraint "source IS NULL AND source_uid IS NULL OR source IS NOT NULL AND source_uid IS NOT NULL AND is_custom = false", name: "exercises_provider_identity"
  end

  add_check_constraint "exercises", "is_custom = true AND coach_id IS NOT NULL OR is_custom = false AND coach_id IS NULL", name: "exercises_custom_ownership", validate: false

  create_table "muscles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_muscles_on_key", unique: true
    t.index ["region"], name: "index_muscles_on_region"
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

  create_table "revenue_cat_webhook_events", force: :cascade do |t|
    t.string "app_user_id"
    t.datetime "created_at", null: false
    t.string "environment"
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_revenue_cat_webhook_events_on_event_id", unique: true
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
    t.string "locale"
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

  add_foreign_key "client_invitations", "users", column: "coach_id"
  add_foreign_key "coach_subscriptions", "users"
  add_foreign_key "exercise_equipment", "equipment"
  add_foreign_key "exercise_equipment", "exercises"
  add_foreign_key "exercise_logs", "workout_exercises"
  add_foreign_key "exercise_logs", "workout_sessions"
  add_foreign_key "exercise_media", "exercises"
  add_foreign_key "exercise_muscles", "exercises"
  add_foreign_key "exercise_muscles", "muscles"
  add_foreign_key "exercise_translations", "exercises"
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
