# frozen_string_literal: true

# Stores non-identifying lifecycle events for asynchronous user deletions.
class UserDeletionEvent < ApplicationRecord
  belongs_to :scheduled_by_admin_user, class_name: "AdminUser", optional: true

  enum :status, {
    requested: 0,
    started: 1,
    succeeded: 2,
    failed: 3
  }

  validates :requested_at, presence: true

  def request_to_success_seconds
    return nil if requested_at.blank? || job_succeeded_at.blank?

    (job_succeeded_at - requested_at).round(2)
  end

  def job_duration_seconds
    return nil if job_started_at.blank? || job_succeeded_at.blank?

    (job_succeeded_at - job_started_at).round(2)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id job_failed_at job_started_at job_succeeded_at requested_at scheduled_by_admin scheduled_by_admin_email status updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
