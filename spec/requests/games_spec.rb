# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games" do
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
    end

    it "defaults the mobile sort control to title order when gaming activity is hidden" do
      user.profile.update!(gaming_activity_privacy: :private)

      get profile_games_path(user.profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<option selected="selected" value="name_asc">Title (A-Z)</option>')
      expect(response.body).not_to include('<option selected="selected" value="last_activity_desc">Last Activity (Newest first)</option>')
    end
  end
end
