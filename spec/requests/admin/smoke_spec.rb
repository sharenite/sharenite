# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin smoke", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:admin_user) { create(:admin_user) }
  let!(:owner) { create(:user, email: "demo-filter@sharenite.local") }
  let!(:invitee) { create(:user, email: "friend-filter@sharenite.local") }

  let!(:profile) do
    owner.profile.tap do |existing_profile|
      existing_profile.update!(
        name: "Demo Filter Profile",
        vanity_url: "demo-filter-profile",
        privacy: :public,
        game_library_privacy: :friendly
      )
    end
  end

  let!(:completion_status) { create(:completion_status, user: owner, name: "Completed") }
  let!(:source) { create(:source, user: owner, name: "Steam") }
  let!(:platform) { create(:platform, user: owner, name: "PC", specification_id: "spec-pc") }
  let!(:category) { create(:category, user: owner, name: "RPG") }
  let!(:tag) { create(:tag, user: owner, name: "Co-op") }

  let!(:genre) { Genre.create!(user: owner, name: "Action") }
  let!(:developer) { Developer.create!(user: owner, name: "Demo Dev") }
  let!(:publisher) { Publisher.create!(user: owner, name: "Demo Pub") }
  let!(:feature) { Feature.create!(user: owner, name: "Cloud Save") }
  let!(:series) { Series.create!(user: owner, name: "Demo Series") }
  let!(:age_rating) { AgeRating.create!(user: owner, name: "PEGI 18") }
  let!(:region) { Region.create!(user: owner, name: "EU") }

  let!(:game) do
    Game.create!(
      user: owner,
      name: "Demo Filter Game",
      completion_status: completion_status,
      source: source
    )
  end

  let!(:rom) { Rom.create!(game: game, name: "Demo Rom", path: "/tmp/demo.rom") }
  let!(:link) { Link.create!(game: game, name: "Demo Link", url: "https://example.com") }

  let!(:friend) { Friend.create!(inviter: owner, invitee: invitee, status: :invited) }

  let!(:playlist) { create(:playlist, user: owner, name: "Demo Playlist") }
  let!(:igdb_cache) { create(:igdb_cache, name: "Demo IGDB") }
  let!(:playlist_item) { create(:playlist_item, playlist: playlist, igdb_cache: igdb_cache, order: 1) }
  let!(:delete_candidate) { create(:user, email: "delete-candidate@sharenite.local") }
  let!(:user_deletion_event) { UserDeletionEvent.create!(requested_at: 1.day.ago, status: :requested) }

  let!(:sync_job) do
    attributes = {
      user: owner,
      name: "FullLibrarySyncJob (chunk 1/2)",
      status: :finished,
      payload_size_bytes: 12_345,
      payload_chunks: 2,
      payload_chunk_index: 0,
      waiting_time: 12,
      processing_time: 34
    }
    attributes[:games_count] = 7 if SyncJob.columns_hash.key?("games_count")
    SyncJob.create!(attributes)
  end

  before do
    game.tags << tag
    game.categories << category
    game.platforms << platform
    game.genres << genre
    game.developers << developer
    game.publishers << publisher
    game.features << feature
    game.series << series
    game.age_ratings << age_rating
    game.regions << region

    sign_in admin_user
  end

  it "renders admin pages" do
    paths = [
      "/admin",
      "/admin/stats",
      "/admin/admin_users",
      "/admin/users",
      "/admin/user_deletion_events",
      "/admin/profiles",
      "/admin/friends",
      "/admin/games",
      "/admin/categories",
      "/admin/completion_statuses",
      "/admin/platforms",
      "/admin/sources",
      "/admin/tags",
      "/admin/roms",
      "/admin/links",
      "/admin/genres",
      "/admin/developers",
      "/admin/publishers",
      "/admin/features",
      "/admin/series",
      "/admin/age_ratings",
      "/admin/regions",
      "/admin/playlists",
      "/admin/playlist_items",
      "/admin/sync_jobs"
    ]

    aggregate_failures do
      paths.each do |path|
        get path
        expect(response).to have_http_status(:ok), "expected #{path} to render"
      end
    end
  end

  it "applies filters without server errors" do
    requests = {
      "/admin/admin_users" => { q: { email_cont: admin_user.email, sign_in_count_eq: "0" } },
      "/admin/users" => { q: { email_cont: owner.email, games_count_gteq: "0", games_count_lteq: "999" } },
      "/admin/user_deletion_events" => { q: { status_eq: "requested" } },
      "/admin/profiles" => { q: { name_cont: "Demo", vanity_url_cont: "demo", privacy_eq: "public", game_library_privacy_eq: "friendly", user_email_cont: owner.email } },
      "/admin/friends" => { q: { inviter_email_cont: owner.email, invitee_email_cont: invitee.email, status_eq: "Any" } },
      "/admin/games" => { q: { name_cont: game.name, user_email_cont: owner.email } },
      "/admin/categories" => { q: { user_email_cont: owner.email } },
      "/admin/completion_statuses" => { q: { user_email_cont: owner.email } },
      "/admin/platforms" => { q: { user_email_cont: owner.email } },
      "/admin/sources" => { q: { user_email_cont: owner.email } },
      "/admin/tags" => { q: { user_email_cont: owner.email } },
      "/admin/roms" => { q: { game_name_cont: game.name } },
      "/admin/links" => { q: { game_name_cont: game.name } },
      "/admin/genres" => { q: { user_email_cont: owner.email } },
      "/admin/developers" => { q: { user_email_cont: owner.email } },
      "/admin/publishers" => { q: { user_email_cont: owner.email } },
      "/admin/features" => { q: { user_email_cont: owner.email } },
      "/admin/series" => { q: { user_email_cont: owner.email } },
      "/admin/age_ratings" => { q: { user_email_cont: owner.email } },
      "/admin/regions" => { q: { user_email_cont: owner.email } },
      "/admin/playlists" => { q: { name_cont: playlist.name, user_email_cont: owner.email } },
      "/admin/playlist_items" => { q: { playlist_id_eq: playlist.id, playlist_name_cont: playlist.name, playlist_user_email_cont: owner.email, playlist_user_profile_name_cont: profile.name } },
      "/admin/sync_jobs" => {
        user_query: owner.email,
        q: {
          user_id_eq: owner.id,
          name_start: "FullLibrarySyncJob",
          status_eq: "Any",
          waiting_time_gteq: "0",
          waiting_time_lteq: "3600",
          processing_time_gteq: "0",
          processing_time_lteq: "3600"
        }
      }
    }

    aggregate_failures do
      requests.each do |path, params|
        get path, params: params
        expect(response).to have_http_status(:ok), "expected filters for #{path} to render"
      end
    end
  end

  it "serves autocomplete suggestions for name/email filters" do
    aggregate_failures do
      get "/admin/filter_autocomplete", params: { resource: "profiles", attribute: "name", q: "de" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)

      get "/admin/filter_autocomplete", params: { resource: "games", attribute: "user_email", q: "de" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)

      get "/admin/playlists/user_options", params: { q: "de" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  it "hides new/edit actions for synced resources" do
    get "/admin/sync_jobs"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("New Sync Job")

    get "/admin/games"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("New Game")

    get "/admin/sync_jobs/#{sync_job.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Edit Sync Job")
  end

  it "preserves filters after delete when return_to is provided" do
    aggregate_failures do
      delete "/admin/friends/#{friend.id}", params: { return_to: "/admin/friends?q%5Binviter_query%5D=demo" }
      expect(response).to redirect_to("/admin/friends?q%5Binviter_query%5D=demo")

      delete "/admin/profiles/#{profile.slug}", params: { return_to: "/admin/profiles?q%5Bname_cont%5D=demo" }
      expect(response).to redirect_to("/admin/profiles?q%5Bname_cont%5D=demo")
    end
  end

  it "renders empty-value Any options for enum-like filters" do
    get "/admin/friends"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(<option value="" selected="selected">Any</option>))

    get "/admin/sync_jobs"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(<option value="" selected="selected">Any</option>))
  end

  it "shows playlist item sidebar links and pre-fills new form from filtered referer" do
    get "/admin/playlist_items/#{playlist_item.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(/admin/playlists/#{playlist.id}))
    expect(response.body).to include(%(/admin/playlist_items?q%5Bplaylist_id_eq%5D=#{playlist.id}))

    get "/admin/playlist_items/new", headers: { "HTTP_REFERER" => "http://localhost/admin/playlist_items?q%5Bplaylist_id_eq%5D=#{playlist.id}" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(name="playlist_item[playlist_id]"))
    expect(response.body).to include(%(value="#{playlist.id}"))
  end

  it "schedules user deletion and preserves filter return path" do
    expect do
      delete "/admin/users/#{delete_candidate.id}", params: { return_to: "/admin/users?q%5Bemail_cont%5D=delete-candidate" }
    end.to change(UserDeletionEvent, :count).by(1)

    expect(response).to redirect_to("/admin/users?q%5Bemail_cont%5D=delete-candidate")

    delete_candidate.reload
    latest_event = UserDeletionEvent.order(:created_at).last
    expect(delete_candidate.deleting).to be(true)
    expect(delete_candidate.deletion_requested_at).to be_present
    expect(delete_candidate.email).to eq("#{delete_candidate.id}@sharenite.link")
    expect(latest_event.scheduled_by_admin).to be(true)
    expect(latest_event.scheduled_by_admin_user_id).to eq(admin_user.id)
    expect(latest_event.scheduled_by_admin_email).to eq(admin_user.email)
  end
end
