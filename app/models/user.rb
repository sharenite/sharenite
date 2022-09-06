# frozen_string_literal: true

# User model
class User < ApplicationRecord
  self.implicit_order_column = "created_at"

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :confirmable, :trackable

  has_many :games, dependent: :destroy
  has_many :sync_jobs, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :platforms, dependent: :destroy
  has_many :completion_statuses, dependent: :destroy
  has_many :sources, dependent: :destroy
  has_one :profile, dependent: :destroy

  after_create :create_profile

  def display_name
    email
  end

  private

  def create_profile
    Profile.create_or_find_by(user: self)
  end
end
