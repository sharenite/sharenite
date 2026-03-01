# frozen_string_literal: true

if Rails.env.development?
  admin_email = ENV.fetch("DEV_SEED_ADMIN_EMAIL", "admin@sharenite.local")
  admin = AdminUser.find_or_initialize_by(email: admin_email)
  if admin.new_record?
    admin.password = "Test123$"
    admin.password_confirmation = "Test123$"
    admin.save!
  end

  demo_user = User.find_or_initialize_by(email: "demo@sharenite.local")
  if demo_user.new_record?
    demo_user.password = "Test123$"
    demo_user.password_confirmation = "Test123$"
    demo_user.confirmed_at = Time.current
    demo_user.save!
  elsif demo_user.confirmed_at.nil?
    demo_user.update!(confirmed_at: Time.current)
  end

  profile = demo_user.profile || Profile.create!(user: demo_user)
  profile.update!(name: "Demo Library", privacy: :public, vanity_url: "demo-library")

  source_names = ["Steam", "GOG", "Epic", "Xbox", "Switch", "Emulator"]
  status_names = ["Backlog", "Playing", "Completed", "Paused", "Dropped"]
  tag_names = ["RPG", "Action", "Indie", "Multiplayer", "Story Rich", "Co-op", "Roguelike"]
  platform_names = ["PC", "PS5", "Xbox Series", "Switch", "Steam Deck"]

  sources = source_names.index_with do |name|
    Source.find_or_create_by!(user: demo_user, name:)
  end
  statuses = status_names.index_with do |name|
    CompletionStatus.find_or_create_by!(user: demo_user, name:)
  end
  tags = tag_names.index_with do |name|
    Tag.find_or_create_by!(user: demo_user, name:)
  end
  platforms = platform_names.index_with do |name|
    Platform.find_or_create_by!(user: demo_user, name:)
  end

  base_titles = [
    "Elden Ring",
    "Hades",
    "Celeste",
    "Baldur's Gate 3",
    "Disco Elysium",
    "The Witcher 3",
    "Slay the Spire",
    "Factorio",
    "Hollow Knight",
    "Forza Horizon 5",
    "Stardew Valley",
    "Dead Cells",
    "Cyberpunk 2077",
    "Sekiro",
    "Portal 2",
    "Control",
    "Doom Eternal",
    "Sea of Thieves",
    "Return of the Obra Dinn",
    "Outer Wilds",
    "Sifu",
    "Risk of Rain 2",
    "Darkest Dungeon",
    "Lies of P",
    "Signalis",
    "Dredge"
  ]

  special_games = [
    { title: "Filter Case A - Fully Empty", source: nil, status: nil, tags: [], platforms: [], notes: nil, user_score: nil, last_activity: nil, favorite: false, installed: false },
    { title: "Filter Case B - Empty Notes", source: "Steam", status: "Backlog", tags: ["Indie"], platforms: ["PC"], notes: "", user_score: nil, last_activity: 2.days.ago, favorite: false, installed: true },
    { title: "Filter Case C - Whitespace Notes", source: "GOG", status: "Playing", tags: [], platforms: ["Steam Deck"], notes: "   ", user_score: nil, last_activity: nil, favorite: true, installed: true },
    { title: "Filter Case D - Review Only", source: nil, status: "Completed", tags: ["Story Rich"], platforms: [], notes: nil, user_score: 5, last_activity: 5.days.ago, favorite: true, installed: false },
    { title: "Filter Case E - Notes Only", source: "Epic", status: nil, tags: ["Action", "Roguelike"], platforms: ["PC"], notes: "Remember to finish final boss.", user_score: nil, last_activity: nil, favorite: false, installed: true },
    { title: "Filter Case F - No Tags", source: "Xbox", status: "Paused", tags: [], platforms: ["Xbox Series"], notes: "Paused at chapter 3.", user_score: 3, last_activity: 8.days.ago, favorite: false, installed: true },
    { title: "Filter Case G - No Status", source: "Switch", status: nil, tags: ["Co-op"], platforms: ["Switch"], notes: "", user_score: nil, last_activity: 12.days.ago, favorite: false, installed: true },
    { title: "Filter Case H - No Source", source: nil, status: "Dropped", tags: ["RPG"], platforms: ["PS5"], notes: nil, user_score: 2, last_activity: nil, favorite: false, installed: false },
    { title: "Filter Case I - No Platform", source: "Emulator", status: "Backlog", tags: ["Action"], platforms: [], notes: "Legacy title", user_score: nil, last_activity: 3.days.ago, favorite: false, installed: false },
    { title: "Filter Case J - Played + Empty Meta", source: nil, status: nil, tags: [], platforms: [], notes: "", user_score: nil, last_activity: 1.day.ago, favorite: false, installed: true }
  ]

  base_titles.each_with_index do |title, index|
    game = Game.find_or_initialize_by(user: demo_user, name: title)
    note_value = case index % 4
                 when 0 then "Seed note #{index + 1} for advanced search validation."
                 when 1 then ""
                 when 2 then "  "
                 else nil
                 end
    score_value = (index % 3).zero? ? nil : ((index % 5) + 1)
    source_value = (index % 6).zero? ? nil : sources[source_names[index % source_names.size]]
    status_value = (index % 5).zero? ? nil : statuses[status_names[index % status_names.size]]

    game.assign_attributes(
      description: "#{title} seed description for search, filtering, and mobile UI testing.",
      notes: note_value,
      source: source_value,
      completion_status: status_value,
      favorite: (index % 4).zero?,
      is_installed: (index % 3) != 2,
      is_custom_game: false,
      hidden: false,
      added: (index + 10).days.ago,
      modified: (index + 3).days.ago,
      last_activity: index.even? ? (index + 1).days.ago : nil,
      play_count: (index + 1) * 2,
      playtime: (index + 1) * 3600,
      release_date: Date.new(2018, 1, 1) + index.months,
      sorting_name: title,
      version: "1.#{index}",
      user_score: score_value,
      community_score: ((index % 5) + 1),
      critic_score: ((index % 5) + 1),
      game_id: "seed-game-#{index + 1}",
      plugin_id: game.plugin_id || SecureRandom.uuid
    )
    game.save!

    if index.even?
      igdb_cache = IgdbCache.find_or_create_by!(igdb_id: 50_000 + index) do |record|
        record.name = "#{title} (IGDB)"
      end
      game.update!(igdb_cache:)
    end

    game.tags = if (index % 4).zero?
                  []
                else
                  [tags[tag_names[index % tag_names.size]], tags[tag_names[(index + 2) % tag_names.size]]].uniq
                end
    game.platforms = (index % 5).zero? ? [] : [platforms[platform_names[index % platform_names.size]]]
  end

  special_games.each_with_index do |config, index|
    game = Game.find_or_initialize_by(user: demo_user, name: config[:title])

    game.assign_attributes(
      description: "#{config[:title]} dedicated filter edge-case seed.",
      notes: config[:notes],
      source: config[:source].present? ? sources[config[:source]] : nil,
      completion_status: config[:status].present? ? statuses[config[:status]] : nil,
      favorite: config[:favorite],
      is_installed: config[:installed],
      is_custom_game: false,
      hidden: false,
      added: (index + 1).days.ago,
      modified: index.days.ago,
      last_activity: config[:last_activity],
      play_count: index + 1,
      playtime: (index + 1) * 900,
      release_date: Date.new(2019, 1, 1) + index.months,
      sorting_name: config[:title],
      version: "2.#{index}",
      user_score: config[:user_score],
      community_score: ((index % 5) + 1),
      critic_score: ((index % 5) + 1),
      game_id: "seed-filter-case-#{index + 1}",
      plugin_id: game.plugin_id || SecureRandom.uuid
    )
    game.save!

    game.tags = Array(config[:tags]).map { |tag_name| tags.fetch(tag_name) }
    game.platforms = Array(config[:platforms]).map { |platform_name| platforms.fetch(platform_name) }
  end

  puts "Seeded demo data: #{demo_user.email} / password: Test123$"
  puts "Games seeded: #{demo_user.games.count}"
  puts "Games with no status: #{demo_user.games.where(completion_status_id: nil).count}"
  puts "Games with no source: #{demo_user.games.where(source_id: nil).count}"
  puts "Games with no tags: #{demo_user.games.left_outer_joins(:tags).where(tags: { id: nil }).distinct.count}"
  puts "Games with no platforms: #{demo_user.games.left_outer_joins(:platforms).where(platforms: { id: nil }).distinct.count}"
  puts "Games without notes/review: #{demo_user.games.where("COALESCE(TRIM(notes), '') = '' AND user_score IS NULL").count}"
end
