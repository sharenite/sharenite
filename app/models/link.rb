# frozen_string_literal: true
class Link < ApplicationRecord
  belongs_to :game

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "game_id", "id", "name", "updated_at", "url"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["game"]
  end
end
