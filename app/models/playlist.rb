# frozen_string_literal: true

# Game model
class Playlist < ApplicationRecord
  has_many :playlist_items, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    ["id", "name", "created_at", "updated_at"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["playlist_items"]
  end
end