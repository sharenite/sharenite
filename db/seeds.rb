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
  profile.update!(
    name: "Demo Library",
    privacy: :members,
    game_library_privacy: :members,
    gaming_activity_privacy: :members,
    playlists_privacy: :members,
    friends_privacy: :members,
    vanity_url: "demo-library"
  )

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

  active_runtime_games = {
    "Showcase - Multi Meta" => { is_running: true },
    "Hades" => { is_launching: true },
    "Dead Cells" => { is_installing: true },
    "Risk of Rain 2" => { is_uninstalling: true }
  }

  active_runtime_games.each do |title, flags|
    game = demo_user.games.find_by(name: title)
    next unless game

    game.update!(flags.merge(last_activity: Time.current))
  end

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

  profile_seed_count = 70
  profile_seed_count.times do |index|
    sequence = index + 1
    seeded_email = format("profile-seed-%03d@sharenite.local", sequence)
    seeded_user = User.find_or_initialize_by(email: seeded_email)
    if seeded_user.new_record?
      seeded_user.password = "Test123$"
      seeded_user.password_confirmation = "Test123$"
      seeded_user.confirmed_at = Time.current
      seeded_user.save!
    elsif seeded_user.confirmed_at.nil?
      seeded_user.update!(confirmed_at: Time.current)
    end

    seeded_profile = seeded_user.profile || Profile.create!(user: seeded_user)
    profile_privacy = (sequence % 11).zero? ? :private : (sequence % 4).zero? ? :friends : :members
    game_privacy = case sequence % 6
                   when 0, 1
                     :members
                   when 2, 3, 4
                     :friends
                   else
                     :private
                   end
    activity_privacy = case sequence % 5
                       when 0
                         :members
                       when 1, 2, 3
                         :friends
                       else
                         :private
                       end
    playlists_privacy = case sequence % 4
                        when 0
                          :members
                        when 1, 2
                          :friends
                        else
                          :private
                        end
    friends_privacy = case sequence % 3
                      when 0
                        :members
                      when 1
                        :friends
                      else
                        :private
                      end
    seeded_profile.update!(
      name: format("Profile Seed %03d", sequence),
      privacy: profile_privacy,
      game_library_privacy: game_privacy,
      gaming_activity_privacy: activity_privacy,
      playlists_privacy: playlists_privacy,
      friends_privacy: friends_privacy,
      vanity_url: format("profile-seed-%03d", sequence)
    )

    seeded_games_count = sequence % 19
    seeded_games_count.times do |game_index|
      game_title = format("Profile Seed %03d Game %02d", sequence, game_index + 1)
      seeded_game = Game.find_or_initialize_by(user: seeded_user, name: game_title)
      seeded_game.assign_attributes(
        description: "Profile pagination seed game #{game_index + 1}.",
        notes: "",
        source: nil,
        completion_status: nil,
        favorite: false,
        is_installed: (game_index % 2).zero?,
        is_custom_game: false,
        hidden: false,
        added: (game_index + 1).days.ago,
        modified: game_index.days.ago,
        last_activity: (game_index % 3).zero? ? (game_index + 2).days.ago : nil,
        play_count: game_index,
        playtime: (game_index + 1) * 300,
        release_date: Date.new(2021, 1, 1) + game_index.days,
        sorting_name: game_title,
        version: "1.#{game_index}",
        user_score: nil,
        community_score: nil,
        critic_score: nil,
        game_id: format("seed-profile-%03d-game-%02d", sequence, game_index + 1),
        plugin_id: seeded_game.plugin_id || SecureRandom.uuid
      )
      seeded_game.save!
    end

    seeded_user.games.where("name LIKE ?", format("Profile Seed %03d Game %%", sequence))
               .order(:name)
               .offset(seeded_games_count)
               .destroy_all
  end

  seeded_profile_user_ids = Profile.where("slug LIKE ?", "profile-seed-%").pluck(:user_id)
  Friend.where(
    "(inviter_id = :demo_user_id AND invitee_id IN (:seeded_ids)) OR " \
    "(invitee_id = :demo_user_id AND inviter_id IN (:seeded_ids))",
    demo_user_id: demo_user.id,
    seeded_ids: seeded_profile_user_ids
  ).delete_all

  # Demo accepted-friend privacy showcase.
  # Expected as demo:
  # profile-seed-001: everything members-only
  # profile-seed-002: all major sections friends-only
  # profile-seed-003: profile friends-only, sections members
  # profile-seed-004: profile members-only, all major sections private
  # profile-seed-005: games friends-only
  # profile-seed-006: activity friends-only
  # profile-seed-007: playlists friends-only
  # profile-seed-008: friends list friends-only
  # profile-seed-009: games private, playlists friends-only, friends private
  # profile-seed-010: games friends-only, activity private, playlists private
  # profile-seed-011: profile friends-only, games private, activity friends-only, playlists members-only
  # profile-seed-012: games members, activity private, playlists friends-only
  # profile-seed-013: blocked by demo, should appear in Blocked tab only
  # profile-seed-014: blocks demo, should be fully invisible to demo
  friend_visibility_showcase = [
    { slug: "profile-seed-001", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :members, playlists_privacy: :members, friends_privacy: :members },
    { slug: "profile-seed-002", privacy: :members, game_library_privacy: :friends, gaming_activity_privacy: :friends, playlists_privacy: :friends, friends_privacy: :friends },
    { slug: "profile-seed-003", privacy: :friends, game_library_privacy: :members, gaming_activity_privacy: :members, playlists_privacy: :members, friends_privacy: :members },
    { slug: "profile-seed-004", privacy: :members, game_library_privacy: :private, gaming_activity_privacy: :private, playlists_privacy: :private, friends_privacy: :private },
    { slug: "profile-seed-005", privacy: :members, game_library_privacy: :friends, gaming_activity_privacy: :members, playlists_privacy: :members, friends_privacy: :members },
    { slug: "profile-seed-006", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :friends, playlists_privacy: :members, friends_privacy: :members },
    { slug: "profile-seed-007", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :members, playlists_privacy: :friends, friends_privacy: :members },
    { slug: "profile-seed-008", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :members, playlists_privacy: :members, friends_privacy: :friends },
    { slug: "profile-seed-009", privacy: :members, game_library_privacy: :private, gaming_activity_privacy: :members, playlists_privacy: :friends, friends_privacy: :private },
    { slug: "profile-seed-010", privacy: :members, game_library_privacy: :friends, gaming_activity_privacy: :private, playlists_privacy: :private, friends_privacy: :friends },
    { slug: "profile-seed-011", privacy: :friends, game_library_privacy: :private, gaming_activity_privacy: :friends, playlists_privacy: :members, friends_privacy: :private },
    { slug: "profile-seed-012", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :private, playlists_privacy: :friends, friends_privacy: :private },
    { slug: "profile-seed-013", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :members, playlists_privacy: :members, friends_privacy: :members },
    { slug: "profile-seed-014", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :members, playlists_privacy: :members, friends_privacy: :members }
  ]

  accepted_friend_slugs = friend_visibility_showcase.map { |config| config.fetch(:slug) }
  blocked_by_demo_slug = accepted_friend_slugs.pop
  blocked_demo_slug = accepted_friend_slugs.pop
  accepted_friend_count = accepted_friend_slugs.size
  accepted_friend_slugs.each_with_index do |seeded_profile_slug, index|
    friend_user = Profile.find_by!(slug: seeded_profile_slug).user

    relation = if index.even?
                 Friend.find_or_initialize_by(inviter: demo_user, invitee: friend_user)
               else
                 Friend.find_or_initialize_by(inviter: friend_user, invitee: demo_user)
               end
    relation.status = :accepted
    relation.save!
  end

  pending_received_count = 10
  pending_received_count.times do |index|
    seeded_profile_slug = format("profile-seed-%03d", accepted_friend_count + index + 1)
    inviter_user = Profile.find_by!(slug: seeded_profile_slug).user
    relation = Friend.find_or_initialize_by(inviter: inviter_user, invitee: demo_user)
    relation.status = :invited
    relation.save!
  end

  pending_sent_count = 5
  pending_sent_count.times do |index|
    seeded_profile_slug = format("profile-seed-%03d", accepted_friend_count + pending_received_count + index + 1)
    invitee_user = Profile.find_by!(slug: seeded_profile_slug).user
    relation = Friend.find_or_initialize_by(inviter: demo_user, invitee: invitee_user)
    relation.status = :invited
    relation.save!
  end

  declined_received_count = 4
  declined_received_count.times do |index|
    seeded_profile_slug = format(
      "profile-seed-%03d",
      accepted_friend_count + pending_received_count + pending_sent_count + index + 1
    )
    inviter_user = Profile.find_by!(slug: seeded_profile_slug).user
    relation = Friend.find_or_initialize_by(inviter: inviter_user, invitee: demo_user)
    relation.status = :declined
    relation.save!
  end

  declined_sent_count = 4
  declined_sent_count.times do |index|
    seeded_profile_slug = format(
      "profile-seed-%03d",
      accepted_friend_count + pending_received_count + pending_sent_count + declined_received_count + index + 1
    )
    invitee_user = Profile.find_by!(slug: seeded_profile_slug).user
    relation = Friend.find_or_initialize_by(inviter: demo_user, invitee: invitee_user)
    relation.status = :declined
    relation.save!
  end

  blocked_by_demo_user = Profile.find_by!(slug: blocked_by_demo_slug).user
  Friend.find_or_initialize_by(inviter: demo_user, invitee: blocked_by_demo_user).tap do |relation|
    relation.status = :blocked
    relation.save!
  end

  blocked_demo_user = Profile.find_by!(slug: blocked_demo_slug).user
  Friend.find_or_initialize_by(inviter: blocked_demo_user, invitee: demo_user).tap do |relation|
    relation.status = :blocked
    relation.save!
  end

  explicit_visibility_showcase = friend_visibility_showcase + [
    { slug: "profile-seed-020", privacy: :members, game_library_privacy: :members, gaming_activity_privacy: :friends, playlists_privacy: :friends, friends_privacy: :members },
    { slug: "profile-seed-021", privacy: :members, game_library_privacy: :friends, gaming_activity_privacy: :private, playlists_privacy: :members, friends_privacy: :friends }
  ]

  explicit_visibility_showcase.each do |config|
    Profile.find_by!(slug: config.fetch(:slug)).update!(config.except(:slug))
  end

  playlist_caches = 40.times.map do |index|
    igdb_id = 95_000 + index
    IgdbCache.find_or_create_by!(igdb_id:) do |record|
      record.name = format("Playlist Cache Seed %03d", index + 1)
    end
  end

  playlist_seed_count = 65
  playlist_seed_count.times do |index|
    sequence = index + 1
    playlist = Playlist.find_or_initialize_by(user: demo_user, name: format("Pagination Playlist %03d", sequence))
    playlist.private_override = (sequence % 3).zero?
    playlist.save!

    items_count = sequence % 12
    playlist.playlist_items.destroy_all
    items_count.times do |item_index|
      playlist.playlist_items.create!(
        order: item_index + 1,
        igdb_cache: playlist_caches[(index + item_index) % playlist_caches.length]
      )
    end
  end

  sync_job_seed_prefix = "Seed Finished Sync Job"
  demo_user.sync_jobs.where("name LIKE ?", "#{sync_job_seed_prefix} %").delete_all

  rng = Random.new(20_260_303)
  sync_job_base_names = %w[FullLibrarySyncJob PartialLibrarySyncJob DeleteGamesSyncJob GameSyncJob]
  sync_job_seed_count = 220
  sync_job_seed_count.times do |index|
    base_job_name = sync_job_base_names.sample(random: rng)
    games_count = rng.rand(1..420)
    waiting_time = rng.rand(1..180)
    processing_time = rng.rand(8..1_400)
    payload_chunks = base_job_name == "GameSyncJob" ? 1 : [1, 1, 1, 2, 2, 3, 4].sample(random: rng)
    payload_chunk_index = payload_chunks == 1 ? 0 : rng.rand(0...payload_chunks)
    payload_size_bytes = (games_count * rng.rand(700..4_800)) + rng.rand(5_000..220_000)
    created_at = rng.rand(140).days.ago + rng.rand(0..86_399).seconds
    started_processing_at = created_at + waiting_time.seconds
    finished_processing_at = started_processing_at + processing_time.seconds

    sync_job_name = if payload_chunks == 1
                      base_job_name
                    else
                      "#{base_job_name} (chunk #{payload_chunk_index + 1}/#{payload_chunks})"
                    end

    attributes = {
      name: sync_job_name,
      status: :finished,
      created_at:,
      updated_at: finished_processing_at,
      started_processing_at:,
      finished_processing_at:,
      waiting_time:,
      processing_time:,
      payload_size_bytes:,
      payload_chunks:,
      payload_chunk_index:
    }
    attributes[:games_count] = games_count if SyncJob.columns_hash.key?("games_count")

    demo_user.sync_jobs.create!(attributes)
  end

  seed_rule_names = %w[
    api_games_authenticated
    auth_unauthenticated
    global_unauthenticated
    profile_games_show_unauthenticated
  ]
  RequestThrottleEvent.where(rule_name: seed_rule_names)
                      .where("request_path LIKE ?", "/seed/%")
                      .delete_all

  now = Time.current
  request_limit_samples = [
    {
      event_type: "throttle",
      rule_name: "api_games_authenticated",
      actor_type: "user",
      actor_key: "user:#{demo_user.id}",
      user: demo_user,
      ip_address: "198.51.100.10",
      request_method: "GET",
      request_path: "/seed/api/v1/games",
      limit_value: 120,
      period_seconds: 60,
      hit_count: 4,
      peak_count: 146,
      started_at: 10.minutes.ago,
      last_seen_at: 2.minutes.ago,
      expires_at: 12.hours.from_now,
      permanent: false
    },
    {
      event_type: "throttle",
      rule_name: "auth_unauthenticated",
      actor_type: "ip",
      actor_key: "ip:203.0.113.10",
      user: nil,
      ip_address: "203.0.113.10",
      request_method: "GET",
      request_path: "/seed/users/sign_in",
      limit_value: 20,
      period_seconds: 60,
      hit_count: 2,
      peak_count: 31,
      started_at: 8.minutes.ago,
      last_seen_at: 90.seconds.ago,
      expires_at: 6.hours.from_now,
      permanent: false
    },
    {
      event_type: "throttle",
      rule_name: "global_unauthenticated",
      actor_type: "ip",
      actor_key: "ip:203.0.113.25",
      user: nil,
      ip_address: "203.0.113.25",
      request_method: "GET",
      request_path: "/seed/profiles/demo-library/games",
      limit_value: 120,
      period_seconds: 60,
      hit_count: 3,
      peak_count: 180,
      started_at: 2.hours.ago,
      last_seen_at: 118.minutes.ago,
      expires_at: 119.minutes.ago,
      permanent: false
    },
    {
      event_type: "block",
      rule_name: "profile_games_show_unauthenticated",
      actor_type: "ip",
      actor_key: "ip:203.0.113.50",
      user: nil,
      ip_address: "203.0.113.50",
      request_method: "GET",
      request_path: "/seed/profiles/demo-library/games/showcase",
      limit_value: 30,
      period_seconds: 60,
      hit_count: 6,
      peak_count: 74,
      escalation_value: 12,
      started_at: 15.minutes.ago,
      last_seen_at: 2.minutes.ago,
      expires_at: nil,
      permanent: true
    },
    {
      event_type: "block",
      rule_name: "auth_unauthenticated",
      actor_type: "ip",
      actor_key: "ip:203.0.113.77",
      user: nil,
      ip_address: "203.0.113.77",
      request_method: "POST",
      request_path: "/seed/users/sign_in",
      limit_value: 20,
      period_seconds: 60,
      hit_count: 3,
      peak_count: 41,
      escalation_value: 10,
      started_at: 2.days.ago,
      last_seen_at: 2.days.ago + 10.minutes,
      expires_at: nil,
      lifted_at: 1.day.ago + 6.hours,
      permanent: true
    }
  ]

  request_limit_samples.each do |attributes|
    event = RequestThrottleEvent.find_or_initialize_by(
      event_type: attributes[:event_type],
      rule_name: attributes[:rule_name],
      actor_key: attributes[:actor_key],
      request_method: attributes[:request_method],
      request_path: attributes[:request_path]
    )
    event.assign_attributes(attributes)
    event.save!
  end

  RequestThrottling.redis.set(
    RequestThrottling.permanent_block_key("203.0.113.50"),
    now.iso8601
  )
  RequestThrottling.redis.del(
    RequestThrottling.permanent_block_key("203.0.113.77")
  )

  puts "Seeded demo data: #{demo_user.email} / password: Test123$"
  puts "Public profiles seeded: #{Profile.privacy_public.count}"
  puts "Members-only profiles seeded: #{Profile.privacy_members.count}"
  puts "Demo friends accepted: #{demo_user.friends.count}"
  puts "Demo accepted friend showcase: #{accepted_friend_slugs.join(', ')}"
  puts "Demo blocked showcase: blocked_by_demo=#{blocked_by_demo_slug}, blocked_demo=#{blocked_demo_slug}"
  puts "Seed profiles with members-only games: #{Profile.where(game_library_privacy: :members).count}"
  puts "Seed profiles with friends-only games: #{Profile.where(game_library_privacy: :friends).count}"
  puts "Demo pending invitations received: #{demo_user.pending_inviters.count}"
  puts "Demo pending invitations sent: #{demo_user.pending_invitees.count}"
  puts "Demo declined invitations received (you declined): #{demo_user.declined_friendlies.count}"
  puts "Demo declined invitations sent (they declined): #{demo_user.declined_friends.count}"
  puts "Demo playlists seeded: #{demo_user.playlists.count}"
  puts "Demo finished sync jobs seeded: #{demo_user.sync_jobs.where(status: :finished).count}"
  puts "Request limit events seeded: #{RequestThrottleEvent.where("request_path LIKE ?", "/seed/%").count}"
  puts "Games seeded: #{demo_user.games.count}"
  puts "Games with no status: #{demo_user.games.where(completion_status_id: nil).count}"
  puts "Games with no source: #{demo_user.games.where(source_id: nil).count}"
  puts "Games with no tags: #{demo_user.games.left_outer_joins(:tags).where(tags: { id: nil }).distinct.count}"
  puts "Games with no categories: #{demo_user.games.left_outer_joins(:categories).where(categories: { id: nil }).distinct.count}"
  puts "Games with no platforms: #{demo_user.games.left_outer_joins(:platforms).where(platforms: { id: nil }).distinct.count}"
  puts "Games without notes/review: #{demo_user.games.where("COALESCE(TRIM(notes), '') = '' AND user_score IS NULL").count}"
end
