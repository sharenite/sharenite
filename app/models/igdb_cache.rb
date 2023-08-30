# frozen_string_literal: true

# Game model
class IgdbCache < ApplicationRecord
  has_many :games, dependent: nil
  has_many :playlist_items, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "igdb_id", "name", "updated_at"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["games"]
  end

  def self.get_by_igdb_id(igdb_id)
    igdb_cache = IgdbCache.find_by(igdb_id: )
    igdb_cache.nil? ? IgdbGetGame.new(igdb_id).call : igdb_cache
  end
end