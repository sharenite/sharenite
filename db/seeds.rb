# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
if Rails.env.development?
  AdminUser.create!(
    email: "xenor@sharenite.link",
    password: "Test123$",
    password_confirmation: "Test123$"
  )
  Game.create!(
    name: Faker::Game.title,
    added: Faker::Time.between(from: DateTime.now - 10, to: DateTime.now - 5),
    community_score: Faker::Number.between(from: 1, to: 5),
    critic_score: Faker::Number.between(from: 1, to: 5),
    description: Faker::Lorem.paragraph,
    favorite: Faker::Boolean.boolean,
    game_id: Faker::Lorem.characters(number: 15),
    game_started_script: Faker::Lorem.paragraph,
    hidden: Faker::Boolean.boolean,
    include_library_plugin_action: Faker::Boolean.boolean,
    install_directory: Faker::File.dir,
    is_custom_game: Faker::Boolean.boolean,
    is_installed: Faker::Boolean.boolean,
    is_installing: Faker::Boolean.boolean,
    is_launching: Faker::Boolean.boolean,
    is_running: Faker::Boolean.boolean,
    is_uninstalling: Faker::Boolean.boolean,
    last_activity: Faker::Time.between(from: DateTime.now - 5, to: DateTime.now),
    manual: Faker::Lorem.characters(number: 15),
    modified: Faker::Time.between(from: DateTime.now - 5, to: DateTime.now),
    notes: Faker::Lorem.paragraph,
    play_count: Faker::Number.between(from: 1, to: 50),
    playtime: Faker::Number.between(from: 1, to: 200000),
    plugin_id: SecureRandom::uuid,
    post_script: Faker::Lorem.paragraph,
    pre_script: Faker::Lorem.paragraph,
    release_date: Faker::Date.between(from: 600.days.ago, to: Date.today),
    sorting_name: Faker::Game.title,
    use_global_game_started_script: Faker::Boolean.boolean,
    use_global_post_script: Faker::Boolean.boolean,
    use_global_pre_script: Faker::Boolean.boolean,
    user_score: Faker::Number.between(from: 1, to: 5),
    version: Faker::Lorem.characters(number: 15),
    user: User.first
  )
end
