# frozen_string_literal: true

# Game model
class Game < ApplicationRecord
  self.implicit_order_column = "created_at"

  belongs_to :user
  belongs_to :completion_status, optional: true
  belongs_to :source, optional: true
  has_and_belongs_to_many :tags
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :platforms
  has_and_belongs_to_many :genres
  has_and_belongs_to_many :developers
  has_and_belongs_to_many :publishers
  has_and_belongs_to_many :features
  has_and_belongs_to_many :series
  has_and_belongs_to_many :age_ratings
  has_and_belongs_to_many :regions
  has_many :links
  has_many :roms

  paginates_per 100

  scope :filter_by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :order_by_last_activity, -> { order("last_activity DESC NULLS LAST") }
end
