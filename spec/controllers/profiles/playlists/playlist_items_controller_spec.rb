# frozen_string_literal: true

require "rails_helper"

RSpec.describe Profiles::Playlists::PlaylistItemsController do
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
