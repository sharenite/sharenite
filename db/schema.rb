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

ActiveRecord::Schema[7.0].define(version: 2022_09_30_120003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "invitation_status", ["invited", "accepted", "declined"]
  create_enum "job_status", ["queued", "running", "finished"]
  create_enum "profile_privacy", ["private", "public", "friendly"]

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

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "playnite_id"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "playnite_id"], name: "index_categories_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "categories_games", id: false, force: :cascade do |t|
    t.uuid "game_id", null: false
    t.uuid "category_id", null: false
    t.index ["category_id", "game_id"], name: "index_categories_games_on_category_id_and_game_id"
    t.index ["game_id", "category_id"], name: "index_categories_games_on_game_id_and_category_id"
  end

  create_table "completion_statuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "playnite_id"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "playnite_id"], name: "index_completion_statuses_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_completion_statuses_on_user_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "friends", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "inviter_id", null: false
    t.uuid "invitee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.enum "status", default: "invited", enum_type: "invitation_status"
    t.index ["invitee_id"], name: "index_friends_on_invitee_id"
    t.index ["inviter_id"], name: "index_friends_on_inviter_id"
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
    t.decimal "play_count", precision: 20
    t.decimal "playtime", precision: 20
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
    t.uuid "completion_status_id"
    t.uuid "source_id"
    t.index ["completion_status_id"], name: "index_games_on_completion_status_id"
    t.index ["source_id"], name: "index_games_on_source_id"
    t.index ["user_id", "playnite_id"], name: "index_games_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_games_on_user_id"
  end

  create_table "games_platforms", id: false, force: :cascade do |t|
    t.uuid "game_id", null: false
    t.uuid "platform_id", null: false
    t.index ["game_id", "platform_id"], name: "index_games_platforms_on_game_id_and_platform_id"
    t.index ["platform_id", "game_id"], name: "index_games_platforms_on_platform_id_and_game_id"
  end

  create_table "games_tags", id: false, force: :cascade do |t|
    t.uuid "game_id", null: false
    t.uuid "tag_id", null: false
    t.index ["game_id", "tag_id"], name: "index_games_tags_on_game_id_and_tag_id"
    t.index ["tag_id", "game_id"], name: "index_games_tags_on_tag_id_and_game_id"
  end

  create_table "platforms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "playnite_id"
    t.string "specification_id"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "playnite_id"], name: "index_platforms_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_platforms_on_user_id"
  end

  create_table "profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.enum "privacy", default: "private", enum_type: "profile_privacy"
    t.string "vanity_url"
    t.string "slug"
    t.index ["slug"], name: "index_profiles_on_slug", unique: true
    t.index ["user_id"], name: "index_profiles_on_user_id"
    t.index ["vanity_url"], name: "index_profiles_on_vanity_url", unique: true
  end

  create_table "sources", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "playnite_id"
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "playnite_id"], name: "index_sources_on_user_id_and_playnite_id", unique: true
    t.index ["user_id"], name: "index_sources_on_user_id"
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

  add_foreign_key "categories", "users"
  add_foreign_key "categories_games", "categories"
  add_foreign_key "categories_games", "games"
  add_foreign_key "completion_statuses", "users"
  add_foreign_key "friends", "users", column: "invitee_id"
  add_foreign_key "friends", "users", column: "inviter_id"
  add_foreign_key "games", "completion_statuses"
  add_foreign_key "games", "sources"
  add_foreign_key "games", "users"
  add_foreign_key "games_platforms", "games"
  add_foreign_key "games_platforms", "platforms"
  add_foreign_key "games_tags", "games"
  add_foreign_key "games_tags", "tags"
  add_foreign_key "platforms", "users"
  add_foreign_key "profiles", "users"
  add_foreign_key "sources", "users"
  add_foreign_key "sync_jobs", "users"
  add_foreign_key "tags", "users"
end
