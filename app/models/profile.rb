# frozen_string_literal: true

# Profile model
class Profile < ApplicationRecord
  extend FriendlyId
  friendly_id :vanity_url, use: :slugged
  validates :vanity_url, uniqueness: { case_sensitive: false }, allow_nil: true
  belongs_to :user

  enum privacy: { private: "private", public: "public", friendly: "friendly" }, _prefix: :privacy

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "id", "name", "privacy", "slug", "updated_at", "user_id", "vanity_url"]
  end

def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end

  private 

  def should_generate_new_friendly_id?
    vanity_url_changed?
  end
 
  def vanity_url_changed?
    changed.include?('vanity_url')
  end
end
