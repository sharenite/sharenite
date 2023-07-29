# frozen_string_literal: true
class Series < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :games

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "id", "name", "playnite_id", "updated_at", "user_id"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["games", "user"]
  end

end
