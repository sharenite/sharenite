# frozen_string_literal: true

# Tracks lifecycle and diagnostics for sync operations triggered by clients.
class SyncJob < ApplicationRecord
  belongs_to :user

  RANSACKABLE_ATTRIBUTES = [
    "created_at",
    "error_message",
    "finished_processing_at",
    "id",
    "name",
    "payload_chunk_index",
    "payload_chunks",
    "payload_size_bytes",
    "processing_time",
    "started_processing_at",
    "status",
    "updated_at",
    "user_id",
    "waiting_time"
  ].freeze

  enum status: { queued: "queued", running: "running", finished: "finished", failed: "failed", dead: "dead" }, _prefix: :status

  scope :active, -> { where(status: %i[queued running failed]) }
  scope :recent_failures, -> { where(status: %i[failed dead]).order(created_at: :desc) }

  def self.ransackable_attributes(_auth_object = nil)
    attributes = RANSACKABLE_ATTRIBUTES.dup
    attributes << "games_count" if columns_hash.key?("games_count")
    attributes << "sync_batch_id" if columns_hash.key?("sync_batch_id")
    attributes
  end

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end
end
