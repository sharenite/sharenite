# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games" do
  around do |example|
    original_perform_caching = ActionController::Base.perform_caching
    original_cache_store = ActionController::Base.cache_store

    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    Rails.cache = ActionController::Base.cache_store
    Rails.cache.clear

    example.run
  ensure
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
    ActionController::Base.perform_caching = original_perform_caching
    ActionController::Base.cache_store = original_cache_store
    Rails.cache = original_cache_store
  end

  describe "GET /index" do
    it "redirects unauthenticated users to profiles list through profile access guard" do
      user = create(:user)
      get profile_games_path(user.profile)

      expect(response).to redirect_to(profiles_path)
    end
  end

  describe "GET /profiles/:profile_id/games(.json)" do
    let(:user) { create(:user) }
    let!(:game) { user.games.create!(name: "JSON Ready Game") }

    before do
      user.profile.update!(privacy: :public, game_library_privacy: :public)
    end

    it "renders the public games index as json" do
      get profile_games_path(user.profile, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to include(include("id" => game.id, "name" => "JSON Ready Game"))
    end

    it "renders the public game show as json" do
      get profile_game_path(user.profile, game, format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to include("id" => game.id, "name" => "JSON Ready Game")
    end

    it "renders the shared profile header on the public game show page" do
      user.profile.update!(name: "Visible Owner", vanity_url: "visible-owner")

      get profile_game_path(user.profile, game)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Owner")
      expect(response.body).to include("Member since")
      expect(response.body).to include("Games")
      expect(response.body).to include("Profile")
    end

    it "does not show edit actions to another viewer on games pages" do
      viewer = create(:user)
      sign_in viewer

      get profile_games_path(user.profile)
      expect(response.body).not_to include(edit_profile_game_path(user.profile, game))

      get profile_game_path(user.profile, game)
      expect(response.body).not_to include(edit_profile_game_path(user.profile, game))
    end

    it "marks My Games active in the main nav on owned game show and edit pages" do
      sign_in user

      get profile_game_path(user.profile, game)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      games_link = document.at_css("a[href='#{profile_games_path(user.profile)}']")
      expect(games_link).to be_present
      expect(games_link.text.strip).to eq("My Games")
      expect(games_link["class"]).to include("active")

      get edit_profile_game_path(user.profile, game)

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      games_link = document.at_css("a[href='#{profile_games_path(user.profile)}']")
      expect(games_link).to be_present
      expect(games_link["class"]).to include("active")
    end

    it "does not expose games when profile privacy is private even if games are public" do
      user.profile.update!(privacy: :private, game_library_privacy: :public)

      get profile_games_path(user.profile)

      expect(response).to redirect_to(profiles_path)
    end

    it "hides privately overridden games from another viewer in the index and show pages" do
      viewer = create(:user)
      game.update!(private_override: true)

      sign_in viewer
      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("JSON Ready Game")

      get profile_game_path(user.profile, game)

      expect(response).to redirect_to(profile_games_path(user.profile))
    end

    it "still shows privately overridden games to the owner" do
      sign_in user
      game.update!(private_override: true)

      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("JSON Ready Game")
      expect(response.body).to include("Private")
    end

    it "does not leak owner-only cached game rows to another viewer" do
      viewer = create(:user)
      game.update!(private_override: true)

      sign_in user
      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(edit_profile_game_path(user.profile, game))
      expect(response.body).to include("Private")

      sign_out user
      sign_in viewer
      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(edit_profile_game_path(user.profile, game))
      expect(response.body).not_to include("Private")
    end

    it "does not expose filter options derived only from privately overridden games" do
      visible_source = user.sources.create!(name: "Visible Source")
      hidden_source = user.sources.create!(name: "Hidden Source")
      game.update!(source: visible_source)
      user.games.create!(name: "Secret Source Game", source: hidden_source, private_override: true)

      get profile_games_path(user.profile)

      expect(response.body).to include("Visible Source")
      expect(response.body).not_to include("Hidden Source")
    end

    it "rejects editing another user's game" do
      viewer = create(:user)
      sign_in viewer

      get edit_profile_game_path(user.profile, game)

      expect(response).to redirect_to(profiles_path)
    end

    it "falls back to name sorting when gaming activity is hidden" do
      user.profile.update!(gaming_activity_privacy: :private)
      user.games.create!(name: "Zeta")
      user.games.create!(name: "Alpha")

      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body.index("Alpha")).to be < response.body.index("Zeta")
      expect(response.body).not_to include("games-sort-link\">Last Activity")
      expect(response.body).not_to include("games-sort-link\">Playtime")
      expect(response.body).not_to include("games-sort-link\">Plays")
    end

    it "defaults the mobile sort control to title order when gaming activity is hidden" do
      user.profile.update!(gaming_activity_privacy: :private)

      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<option selected="selected" value="name_asc">Title (A-Z)</option>')
      expect(response.body).not_to include('<option selected="selected" value="last_activity_desc">Last Activity (Newest first)</option>')
      expect(response.body).not_to include('value="play_count_desc">Plays (Highest first)</option>')
    end

    it "hides play counts from another viewer when gaming activity is hidden" do
      user.profile.update!(gaming_activity_privacy: :private)
      game.update!(play_count: 42)

      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(">Plays<")
      expect(response.body).not_to include(">42<")

      get profile_game_path(user.profile, game)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Play count")
      expect(response.body).not_to include(">42<")
    end
  end
end
