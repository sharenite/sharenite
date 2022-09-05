# frozen_string_literal: true

# User model
class User < ApplicationRecord
  self.implicit_order_column = "created_at"

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable,
         :trackable

  has_many :games, dependent: :destroy
  has_many :sync_jobs, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :platforms, dependent: :destroy

  def display_name
    email
  end
end
