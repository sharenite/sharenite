# frozen_string_literal: true
class AgeRating < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :games
end
