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
  category_names = ["Campaign", "Endless", "Party", "Classic", "Retro", "VR", "Family"]
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
  categories = category_names.index_with do |name|
    Category.find_or_create_by!(user: demo_user, name:)
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
    game.categories = if (index % 3).zero?
                        []
                      else
                        [categories[category_names[index % category_names.size]]]
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
    game.categories = if index.even?
                        []
                      else
                        [categories[category_names[index % category_names.size]]]
                      end
    game.platforms = Array(config[:platforms]).map { |platform_name| platforms.fetch(platform_name) }
  end

  pagination_game_count = 140
  pagination_game_count.times do |index|
    title = format("Pagination Seed %03d", index + 1)
    game = Game.find_or_initialize_by(user: demo_user, name: title)

    game.assign_attributes(
      description: "Pagination stress-test game ##{index + 1}.",
      notes: (index % 6).zero? ? nil : "",
      source: (index % 5).zero? ? nil : sources[source_names[index % source_names.size]],
      completion_status: (index % 4).zero? ? nil : statuses[status_names[index % status_names.size]],
      favorite: (index % 9).zero?,
      is_installed: (index % 3) != 1,
      is_custom_game: false,
      hidden: false,
      added: (index + 40).days.ago,
      modified: (index + 10).days.ago,
      last_activity: (index % 2).zero? ? (index + 1).hours.ago : nil,
      play_count: index % 25,
      playtime: (index + 1) * 120,
      release_date: Date.new(2020, 1, 1) + index.days,
      sorting_name: title,
      version: "3.#{index}",
      user_score: (index % 7).zero? ? nil : ((index % 5) + 1),
      community_score: ((index % 5) + 1),
      critic_score: ((index % 5) + 1),
      game_id: "seed-pagination-#{index + 1}",
      plugin_id: game.plugin_id || SecureRandom.uuid
    )
    game.save!

    game.tags = if (index % 5).zero?
                  []
                else
                  [tags[tag_names[index % tag_names.size]]]
                end
    game.categories = if (index % 4).zero?
                        []
                      else
                        [categories[category_names[index % category_names.size]]]
                      end
    game.platforms = if (index % 6).zero?
                       []
                     else
                       [platforms[platform_names[index % platform_names.size]]]
                     end
  end

  showcase_game = Game.find_or_initialize_by(user: demo_user, name: "Showcase - Multi Meta")
  showcase_game.assign_attributes(
    description: "Single showcase game with dense metadata for responsive list/details testing.",
    notes: "Use this game to verify pills wrapping and details blocks on all breakpoints.",
    source: sources["Steam"],
    completion_status: statuses["Playing"],
    favorite: true,
    is_installed: true,
    is_custom_game: false,
    hidden: false,
    added: 3.days.ago,
    modified: 6.hours.ago,
    last_activity: 2.hours.ago,
    play_count: 42,
    playtime: 54_000,
    release_date: Date.new(2022, 11, 18),
    sorting_name: "Showcase - Multi Meta",
    version: "9.9",
    user_score: 5,
    community_score: 4,
    critic_score: 4,
    game_id: "seed-showcase-multi-meta",
    plugin_id: showcase_game.plugin_id || SecureRandom.uuid
  )
  showcase_game.save!

  showcase_igdb = IgdbCache.find_or_create_by!(igdb_id: 90_001) do |record|
    record.name = "Showcase - Multi Meta (IGDB)"
  end
  showcase_game.update!(igdb_cache: showcase_igdb)

  showcase_game.tags = [
    tags["RPG"],
    tags["Action"],
    tags["Story Rich"],
    tags["Co-op"]
  ]
  showcase_game.categories = [
    categories["Campaign"],
    categories["Party"],
    categories["VR"]
  ]
  showcase_game.platforms = [
    platforms["PC"],
    platforms["PS5"],
    platforms["Steam Deck"]
  ]

  puts "Seeded demo data: #{demo_user.email} / password: Test123$"
  puts "Games seeded: #{demo_user.games.count}"
  puts "Games with no status: #{demo_user.games.where(completion_status_id: nil).count}"
  puts "Games with no source: #{demo_user.games.where(source_id: nil).count}"
  puts "Games with no tags: #{demo_user.games.left_outer_joins(:tags).where(tags: { id: nil }).distinct.count}"
  puts "Games with no categories: #{demo_user.games.left_outer_joins(:categories).where(categories: { id: nil }).distinct.count}"
  puts "Games with no platforms: #{demo_user.games.left_outer_joins(:platforms).where(platforms: { id: nil }).distinct.count}"
  puts "Games without notes/review: #{demo_user.games.where("COALESCE(TRIM(notes), '') = '' AND user_score IS NULL").count}"
end
