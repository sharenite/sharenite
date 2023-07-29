# frozen_string_literal: true
class Source < ApplicationRecord
  belongs_to :user
  has_many :games, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "id", "name", "playnite_id", "updated_at", "user_id"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["games", "user"]
  end
end
