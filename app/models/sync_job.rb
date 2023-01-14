# frozen_string_literal: true
class SyncJob < ApplicationRecord
  belongs_to :user

  enum status: { queued: "queued", running: "running", finished: "finished", failed: "failed", dead: "dead" }, _prefix: :status

  scope :active, -> { where(status: %i[queued running failed]) }
end
