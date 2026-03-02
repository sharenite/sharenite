# frozen_string_literal: true

require "rails_helper"

RSpec.describe Profiles::Playlists::PlaylistItemsController do
  describe "POST #create" do
    let(:owner) { create(:user) }
    let(:playlist) { create(:playlist, user: owner) }

    before { sign_in owner }

    it "renders inline error when IGDB id is not found" do
      allow(IgdbCache).to receive(:get_by_igdb_id).with("999999").and_return(nil)

      post :create,
           params: {
             profile_id: owner.profile.slug,
             playlist_id: playlist.id,
             playlist_item: {
               order: 1,
               igdb_cache: { igdb_id: "999999" }
             }
           },
           format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("IGDB entry was not found for ID 999999.")
    end
  end

  describe "PATCH #update" do
    let(:owner) { create(:user) }
    let(:playlist) { create(:playlist, user: owner) }
    let(:playlist_item) { create(:playlist_item, playlist:, order: 1) }

    before { sign_in owner }

    it "renders inline error when IGDB id is not found" do
      allow(IgdbCache).to receive(:get_by_igdb_id).with("888888").and_return(nil)

      patch :update,
            params: {
              profile_id: owner.profile.slug,
              playlist_id: playlist.id,
              id: playlist_item.id,
              playlist_item: {
                order: 1,
                igdb_cache: { igdb_id: "888888" }
              }
            },
            format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("IGDB entry was not found for ID 888888.")
    end
  end

  describe "PATCH #reorder" do
    let(:owner) { create(:user) }
    let(:playlist) { create(:playlist, user: owner) }
    let!(:first) { create(:playlist_item, playlist:, order: 1) }
    let!(:second) { create(:playlist_item, playlist:, order: 2) }
    let!(:third) { create(:playlist_item, playlist:, order: 3) }

    it "reorders playlist items for the owner" do
      sign_in owner

      patch :reorder,
            params: {
              profile_id: owner.profile.slug,
              playlist_id: playlist.id,
              ordered_ids: [third.id, first.id, second.id]
            },
            format: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("ok" => true)
      expect(playlist.playlist_items.order(:order).pluck(:id)).to eq([third.id, first.id, second.id])
    end

    it "redirects non-owner to their own playlists page" do
      intruder = create(:user)
      sign_in intruder

      patch :reorder,
            params: {
              profile_id: owner.profile.slug,
              playlist_id: playlist.id,
              ordered_ids: [third.id, first.id, second.id]
            },
            format: :json

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(profile_playlists_path(intruder.profile))
    end
  end
end
