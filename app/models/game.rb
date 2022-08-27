# frozen_string_literal: true

# Game model
class Game < ApplicationRecord
  self.implicit_order_column = "created_at"

  belongs_to :user
end
