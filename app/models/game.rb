# frozen_string_literal: true

# Game model
class Game < ApplicationRecord
  self.implicit_order_column = "created_at"

  belongs_to :user
  has_and_belongs_to_many :tags

  paginates_per 100

  scope :filter_by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :order_by_last_activity, -> { order("last_activity DESC NULLS LAST") }
end
