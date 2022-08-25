# frozen_string_literal: true

require "rails_helper"

# RSpec.describe API::V1::Games, type: :controller do
RSpec.describe API::V1::Games do
  include Rack::Test::Methods

  def app
    API::V1::Games
  end

  context "when calling GET /games/" do
    let(:user) { create(:user) }

    before do
      Grape::Endpoint.before_each do |endpoint|
        allow(endpoint).to receive(:current_user).and_return(user)
      end
    end

    after { Grape::Endpoint.before_each nil }

    it "returns an empty array of games" do
      get "/api/v1/games"
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to eq []
    end

    context "when calling POST /api/statuses" do
      it "creates games" do
        games = [{ name: "First game title" }, { name: "Second game title" }]
        post "/api/v1/games",
             games: games,
             session: {
               "CONTENT_TYPE" => "application/json"
             }
        expect(last_response.status).to eq 201
        expect(last_response.body).to include games[0][:name].to_json
        expect(last_response.body).to include games[1][:name].to_json
      end
    end
  end
end
