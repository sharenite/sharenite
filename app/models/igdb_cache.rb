# frozen_string_literal: true

# Game model
class IgdbCache < ApplicationRecord
  has_many :games, dependent: nil

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "igdb_id", "name", "updated_at"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["games"]
  end
end

