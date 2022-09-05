# frozen_string_literal: true
class CompletionStatus < ApplicationRecord
  belongs_to :user
  has_many :games, dependent: :destroy
end
