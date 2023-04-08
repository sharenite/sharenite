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
  has_many :genres, dependent: :destroy
  has_many :developers, dependent: :destroy
  has_many :publishers, dependent: :destroy
  has_many :features, dependent: :destroy
  has_many :series, dependent: :destroy
  has_many :age_ratings, dependent: :destroy
  has_many :regions, dependent: :destroy
  has_one :profile, dependent: :destroy

  has_many :invitees, foreign_key: :inviter_id, class_name: 'Friend', dependent: :destroy, inverse_of: :inviter
  has_many :pending_invitees, -> { where(friends: {status: :invited}) }, foreign_key: :inviter_id, class_name: 'Friend', dependent: :destroy, inverse_of: :inviter
  has_many :active_friends, -> { where(friends: {status: :accepted}) }, through: :invitees, source: :invitee
  has_many :invited_friends, -> { where(friends: {status: :invited}) }, through: :invitees, source: :invitee
  has_many :declined_friends, -> { where(friends: {status: :declined}) }, through: :invitees, source: :invitee

  has_many :inviters, foreign_key: :invitee_id, class_name: 'Friend', dependent: :destroy, inverse_of: :invitee
  has_many :pending_inviters, -> { where(friends: {status: :invited}) }, foreign_key: :invitee_id, class_name: 'Friend', dependent: :destroy, inverse_of: :inviter
  has_many :active_friendlies, -> { where(friends: {status: :accepted}) }, through: :inviters, source: :inviter
  has_many :pending_friendlies, -> { where(friends: {status: :invited}) }, through: :inviters, source: :inviter
  has_many :declined_friendlies, -> { where(friends: {status: :declined}) }, through: :inviters, source: :inviter

  after_create :create_profile

  def friends
    active_friends + active_friendlies
  end

  def display_name
    email
  end

  private

  def create_profile
    Profile.create_or_find_by!(user: self)
  end
end
