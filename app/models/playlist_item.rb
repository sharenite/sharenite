# frozen_string_literal: true

# Game model
class PlaylistItem < ApplicationRecord
  belongs_to :playlist, dependent: :destroy
  belongs_to :igdb_cache, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    ["id", "playlist_id", "igdb_cache_id", "order", "created_at", "updated_at"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["playlist, igdb_caches"]
  end

  def self.add_by_igdb_id(playlist_id, igdb_id)
    playlist = Playlist.find(playlist_id)
    igdb_cache = IgdbCache.get_by_igdb_id(igdb_id)
    last_playlist_item = PlaylistItem.where(playlist:).order(order: :desc)&.first || 0
    PlaylistItem.create(playlist:, igdb_cache:, order: last_playlist_item.order + 1)
  end
end