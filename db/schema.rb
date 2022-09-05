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

ActiveRecord::Schema[7.0].define(version: 2022_09_05_162657) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "job_status", ["queued", "running", "finished"]

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "games", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "added"
    t.integer "community_score"
    t.integer "critic_score"
    t.text "description"
    t.boolean "favorite"
    t.string "game_id"
    t.text "game_started_script"
    t.boolean "hidden"
    t.boolean "include_library_plugin_action"
    t.string "install_directory"
    t.boolean "is_custom_game"
    t.boolean "is_installed"
    t.boolean "is_installing"
    t.boolean "is_launching"
    t.boolean "is_running"
    t.boolean "is_uninstalling"
    t.datetime "last_activity"
    t.string "manual"
    t.datetime "modified"
    t.text "notes"
    t.bigint "play_count"
    t.bigint "playtime"
    t.uuid "plugin_id"
    t.text "post_script"
    t.text "pre_script"
    t.date "release_date"
    t.string "sorting_name"
    t.boolean "use_global_game_started_script"
    t.boolean "use_global_post_script"
    t.boolean "use_global_pre_script"
    t.integer "user_score"
    t.string "version"
    t.uuid "playnite_id"
    t.index ["user_id", "playnite_id"], name: "index_games_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_games_on_user_id"
  end

  create_table "games_tags", id: false, force: :cascade do |t|
    t.uuid "game_id", null: false
    t.uuid "tag_id", null: false
    t.uuid "games_id"
    t.uuid "tags_id"
    t.index ["games_id"], name: "index_games_tags_on_games_id"
    t.index ["tags_id"], name: "index_games_tags_on_tags_id"
  end

  create_table "sync_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.enum "status", default: "queued", enum_type: "job_status"
    t.index ["user_id"], name: "index_sync_jobs_on_user_id"
  end

  create_table "tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "playnite_id"
    t.index ["user_id", "playnite_id"], name: "index_tags_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "games", "users"
  add_foreign_key "games_tags", "games", column: "games_id"
  add_foreign_key "games_tags", "tags", column: "tags_id"
  add_foreign_key "sync_jobs", "users"
  add_foreign_key "tags", "users"
end
