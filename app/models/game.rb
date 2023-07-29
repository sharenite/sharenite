# frozen_string_literal: true

# Game model
class Game < ApplicationRecord
  include SearchCop
  self.implicit_order_column = "created_at"

  belongs_to :user
  belongs_to :completion_status, optional: true
  belongs_to :source, optional: true
  has_and_belongs_to_many :tags
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :platforms
  has_and_belongs_to_many :genres
  has_and_belongs_to_many :developers
  has_and_belongs_to_many :publishers
  has_and_belongs_to_many :features
  has_and_belongs_to_many :series
  has_and_belongs_to_many :age_ratings
  has_and_belongs_to_many :regions
  has_many :links, dependent: :destroy
  has_many :roms, dependent: :destroy

  paginates_per 100

  scope :filter_by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :order_by_last_activity, -> { order("last_activity DESC NULLS LAST") }

  search_scope :search do
    attributes :name, :added, :description, :favorite, :hidden, :is_installed, :is_installing, :is_launching,
    :is_running, :is_uninstalling, :last_activity, :modified, :play_count, :playtime, :sorting_name, :release_date,
    :install_size, :recent_activity
    attributes tags: "tags.name"
    attributes categories: "categories.name"
    attributes platforms: "platforms.name"
    attributes genres: "genres.name"
    attributes developers: "developers.name"
    attributes publishers: "publishers.name"
    attributes features: "features.name"
    attributes series: "series.name"
    attributes age_ratings: "age_ratings.name"
    attributes regions: "regions.name"
    attributes completion_status: "completion_status.name"
    attributes source: "source.name"
  end

  def self.ransackable_attributes(_auth_object = nil)
    ["added", "community_score", "completion_status_id", "created_at", "critic_score", "description", "enable_system_hdr", "favorite", "game_id", "game_started_script", "hidden", "id", 
"include_library_plugin_action", "install_directory", "install_size", "is_custom_game", "is_installed", "is_installing", "is_launching", "is_running", "is_uninstalling", "last_activity", 
"last_size_scan_date", "manual", "modified", "name", "notes", "override_install_state", "play_count", "playnite_id", "playtime", "plugin_id", "post_script", "pre_script", "recent_activity", 
"release_date", "sorting_name", "source_id", "updated_at", "use_global_game_started_script", "use_global_post_script", "use_global_pre_script", "user_id", "user_score", "version"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["age_ratings", "categories", "completion_status", "developers", "features", "genres", "links", "platforms", "publishers", "regions", "roms", "series", "source", "tags", "user"]
  end
end

