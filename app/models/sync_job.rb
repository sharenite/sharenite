# frozen_string_literal: true

# Stores metadata for each library sync operation enqueued from API/plugin.
class SyncJob < ApplicationRecord
  belongs_to :user

  enum status: { queued: "queued", running: "running", finished: "finished", failed: "failed", dead: "dead" }, _prefix: :status

  scope :active, -> { where(status: %i[queued running]) }
  scope :recent_failures, -> { where(status: %i[failed dead]).order(created_at: :desc) }

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "finished_processing_at", "id", "name", "processing_time", "started_processing_at", "status", "updated_at", "user_id", "waiting_time"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end
end
