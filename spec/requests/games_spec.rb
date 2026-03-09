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
  end
end
