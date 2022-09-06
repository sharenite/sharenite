# frozen_string_literal: true

# Profile model
class Profile < ApplicationRecord
  extend FriendlyId
  friendly_id :vanity_url, use: :slugged
  validates :vanity_url, uniqueness: { case_sensitive: false }
  belongs_to :user

  enum privacy: { private: "private", public: "public", friendly: "friendly" }, _prefix: :privacy

  private 

  def should_generate_new_friendly_id?
    vanity_url_changed?
  end
 
  def vanity_url_changed?
    changed.include?('vanity_url')
  end
end
