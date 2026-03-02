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
    normalized_igdb_id = normalize_igdb_id(igdb_id)
    return nil if normalized_igdb_id.nil?

    igdb_cache = IgdbCache.find_by(igdb_id: normalized_igdb_id)
    igdb_cache.nil? ? IgdbGetGame.new(normalized_igdb_id).call : igdb_cache
  end

  def self.normalize_igdb_id(igdb_id)
    value = igdb_id.to_s.strip
    return nil unless /\A\d+\z/.match?(value)

    value.to_i
  end
end
