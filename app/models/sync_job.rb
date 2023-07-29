# frozen_string_literal: true
class SyncJob < ApplicationRecord
  belongs_to :user

  enum status: { queued: "queued", running: "running", finished: "finished", failed: "failed", dead: "dead" }, _prefix: :status

  scope :active, -> { where(status: %i[queued running failed]) }

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "finished_processing_at", "id", "name", "processing_time", "started_processing_at", "status", "updated_at", "user_id", "waiting_time"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end
end
