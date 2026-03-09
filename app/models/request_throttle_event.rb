# frozen_string_literal: true

class RequestThrottleEvent < ApplicationRecord
  EVENT_TYPES = %w[throttle block].freeze
  ACTOR_TYPES = %w[ip user].freeze
  RANSACKABLE_ATTRIBUTES = %w[
    actor_key
    actor_type
    created_at
    escalation_value
    event_type
    expires_at
    hit_count
    id
    ip_address
    last_seen_at
    limit_value
    peak_count
    period_seconds
    permanent
    request_method
    request_path
    rule_name
    started_at
    lifted_at
    updated_at
    user_id
  ].freeze

  belongs_to :user, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :actor_type, inclusion: { in: ACTOR_TYPES }
  validates :rule_name, :actor_key, :ip_address, :request_method, :request_path, presence: true
  validates :limit_value, :period_seconds, numericality: { greater_than: 0 }
  validates :hit_count, :peak_count, numericality: { greater_than_or_equal_to: 0 }

  scope :current, lambda {
    now = Time.current
    where(lifted_at: nil)
      .where("permanent = ? OR expires_at > ?", true, now)
  }
  scope :historical, lambda {
    now = Time.current
    where("lifted_at IS NOT NULL OR (permanent = ? AND expires_at <= ?)", false, now)
  }
  scope :throttle_events, -> { where(event_type: "throttle") }
  scope :block_events, -> { where(event_type: "block") }
  scope :permanent_blocks, -> { block_events.where(permanent: true) }

  def current?(reference_time = Time.current)
    return false if lifted_at.present?
    return true if permanent?

    expires_at.present? && expires_at > reference_time
  end

  def subject_label
    return user&.email.presence || actor_key if actor_type == "user"

    ip_address
  end

  def status_label(reference_time = Time.current)
    current?(reference_time) ? "current" : "historical"
  end

  def self.ransackable_attributes(_auth_object = nil)
    RANSACKABLE_ATTRIBUTES
  end

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end
end
