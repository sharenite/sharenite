# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games API", type: :request do
  let(:user) { create(:user) }
  let(:games) { [{ id: "1", name: "First game title" }, { id: "2", name: "Second game title" }] }

  it "rejects an anonymous upload without creating sync jobs" do
    expect do
      post "/api/v1/games", params: { games: }, as: :json
    end.not_to change(SyncJob, :count)

    expect(response).to have_http_status(:unauthorized)
  end

  context "with an authenticated user" do
    before do
      sign_in user
    end

    it "returns an empty array of games" do
      get "/api/v1/games"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns only the authenticated user's games" do
      game = user.games.create!(name: "My game")
      create(:user).games.create!(name: "Someone else's game")

      get "/api/v1/games"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq([{ "id" => game.id, "name" => "My game" }])
    end

    it "queues uploaded games for the authenticated user" do
      # rubocop:disable-next Style/GlobalVars
      allow($redis).to receive(:set).and_return("OK")
      allow(Karafka.producer).to receive(:produce_sync)

      expect do
        post "/api/v1/games", params: { games: }, as: :json
      end.to change(user.sync_jobs, :count).by(1)

      expect(response).to have_http_status(:accepted)
      expect(Karafka.producer).to have_received(:produce_sync).with(
        hash_including(topic: "library.sync", key: user.id, partition_key: user.id)
      )
    end

    it "returns a JSON error for an upload without game IDs" do
      expect do
        post "/api/v1/games", params: { games: [{ name: "Missing ID" }] }, as: :json
      end.not_to change(SyncJob, :count)

      expect(response).to have_http_status(:internal_server_error)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq("error" => "Incorrect parameters, check for plugin updates")
    end

    it "rejects malformed JSON without creating sync jobs" do
      expect do
        post "/api/v1/games", params: '{"games":', headers: { "CONTENT_TYPE" => "application/json" }
      end.not_to change(SyncJob, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to have_key("error")
    end
  end
end
