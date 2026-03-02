# frozen_string_literal: true

# Game model
class PlaylistItem < ApplicationRecord
  belongs_to :playlist
  belongs_to :igdb_cache

  # rubocop:disable Rails/I18nLocaleTexts
  validates :igdb_cache_id,
            uniqueness: { scope: :playlist_id, message: "IGDB ID is already added to this playlist." }
  validates :order, presence: true
  validates :order, uniqueness: { scope: :playlist_id, message: "position is already used in this playlist" }
  # rubocop:enable Rails/I18nLocaleTexts

  after_commit :normalize_playlist_orders_after_create, on: :create
  after_commit :normalize_playlist_orders_after_update, on: :update
  after_commit :normalize_playlist_orders_after_destroy, on: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    ["id", "playlist_id", "igdb_cache_id", "order", "created_at", "updated_at"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["playlist, igdb_caches"]
  end

  def self.add_by_igdb_id(playlist_id, igdb_id)
    playlist = Playlist.find(playlist_id)
    igdb_cache = IgdbCache.get_by_igdb_id(igdb_id)
    last_playlist_item = PlaylistItem.where(playlist:).order(order: :desc)&.first
    PlaylistItem.create(playlist:, igdb_cache:, order: (last_playlist_item&.order || 0) + 1)
  end

  def self.reorder_for_playlist!(playlist, ordered_ids)
    scope = where(playlist_id: playlist.id)
    existing_ids = scope.order(:order, :created_at, :id).pluck(:id).map(&:to_s)
    return if existing_ids.empty?

    requested = Array(ordered_ids).map(&:to_s)
    ordered = requested.select { |id| existing_ids.include?(id) }
    ordered += existing_ids - ordered
    return if ordered == existing_ids

    apply_order!(scope, ordered)
  end

  # rubocop:disable Metrics/AbcSize
  def self.move_to_position!(playlist, item_id, desired_position)
    scope = where(playlist_id: playlist.id)
    existing_ids = scope.order(:order, :created_at, :id).pluck(:id).map(&:to_s)
    item_id = item_id.to_s
    return unless existing_ids.include?(item_id)

    ordered = existing_ids - [item_id]
    target_index = desired_position.to_i - 1
    target_index = 0 if target_index.negative?
    target_index = ordered.length if target_index > ordered.length
    ordered.insert(target_index, item_id)
    apply_order!(scope, ordered)
  end
  # rubocop:enable Metrics/AbcSize

  def self.normalize_for_playlist_id!(playlist_id)
    scope = where(playlist_id:)
    ordered_ids = scope.order(:order, :created_at, :id).pluck(:id).map(&:to_s)
    return if ordered_ids.empty?

    apply_order!(scope, ordered_ids)
  end

  # rubocop:disable Rails/SkipsModelValidations
  def self.apply_order!(scope, ordered_ids)
    transaction do
      scope.where(id: ordered_ids).update_all("\"order\" = \"order\" + 100000")
      ordered_ids.each_with_index do |id, index|
        scope.where(id:).update_all(order: index + 1)
      end
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  private

  def normalize_playlist_orders_after_create
    self.class.normalize_for_playlist_id!(playlist_id)
  end

  def normalize_playlist_orders_after_update
    return unless saved_change_to_order? || saved_change_to_playlist_id?

    self.class.normalize_for_playlist_id!(playlist_id)
  end

  def normalize_playlist_orders_after_destroy
    self.class.normalize_for_playlist_id!(playlist_id)
  end
end
