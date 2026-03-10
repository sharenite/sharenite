# frozen_string_literal: true

# Profile model
class Profile < ApplicationRecord
  extend FriendlyId
  friendly_id :vanity_url, use: :slugged
  attr_accessor :user_query
  validates :vanity_url, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :user_id, uniqueness: true
  belongs_to :user

  enum privacy: { private: "private", friends: "friends", members: "members", public: "public" }, _prefix: :privacy
  attribute :privacy, :string, default: "friends"
  attribute :game_library_privacy, :string, default: "friends"
  enum game_library_privacy: { private: "private", friends: "friends", members: "members", public: "public" }, _prefix: :game_library_privacy
  attribute :gaming_activity_privacy, :string, default: "friends"
  enum gaming_activity_privacy: { private: "private", friends: "friends", members: "members", public: "public" }, _prefix: :gaming_activity_privacy
  attribute :playlists_privacy, :string, default: "friends"
  enum playlists_privacy: { private: "private", friends: "friends", members: "members", public: "public" }, _prefix: :playlists_privacy
  attribute :friends_privacy, :string, default: "friends"
  enum friends_privacy: { private: "private", friends: "friends", members: "members", public: "public" }, _prefix: :friends_privacy

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "friends_privacy", "game_library_privacy", "gaming_activity_privacy", "id", "name", "playlists_privacy", "privacy", "slug", "updated_at", "user_id", "vanity_url"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end

  def visible_to?(viewer)
    return false if blocked_with?(viewer)

    privacy_allows?(privacy, viewer)
  end

  def game_library_visible_to?(viewer)
    visible_to?(viewer) && privacy_allows?(game_library_privacy, viewer)
  end

  def friends_list_visible_to?(viewer)
    visible_to?(viewer) && privacy_allows?(friends_privacy, viewer)
  end

  def gaming_activity_visible_to?(viewer)
    visible_to?(viewer) && privacy_allows?(gaming_activity_privacy, viewer)
  end

  def playlists_visible_to?(viewer)
    visible_to?(viewer) && privacy_allows?(playlists_privacy, viewer)
  end

  def friends_with?(viewer)
    return false unless viewer
    return false if blocked_with?(viewer)

    Friend.where(status: :accepted).exists?(
      ["(inviter_id = :viewer_id AND invitee_id = :profile_user_id) OR " \
       "(invitee_id = :viewer_id AND inviter_id = :profile_user_id)",
       {
         viewer_id: viewer.id,
         profile_user_id: user_id
       }]
    )
  end

  private

  def blocked_with?(viewer)
    return false unless viewer

    Friend.where(status: :blocked).exists?(
      ["(inviter_id = :viewer_id AND invitee_id = :profile_user_id) OR " \
       "(invitee_id = :viewer_id AND inviter_id = :profile_user_id)",
       {
         viewer_id: viewer.id,
         profile_user_id: user_id
       }]
    )
  end

  def should_generate_new_friendly_id?
    vanity_url_changed?
  end

  def vanity_url_changed?
    changed.include?("vanity_url")
  end

  def privacy_allows?(setting, viewer)
    return true if own_profile_for?(viewer)

    case setting
    when "public"
      true
    when "members"
      viewer.present?
    when "friends"
      friends_with?(viewer)
    else
      false
    end
  end

  def own_profile_for?(viewer)
    viewer.present? && viewer.id == user_id
  end
end
