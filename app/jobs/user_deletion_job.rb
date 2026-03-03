# frozen_string_literal: true

class UserDeletionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(user_id, deletion_event_id = nil)
    deletion_event = UserDeletionEvent.find_by(id: deletion_event_id)
    mark_job_started!(deletion_event)

    user = User.find_by(id: user_id)
    return unless user&.deleting?

    user.destroy!
    mark_job_succeeded!(deletion_event)
  rescue StandardError
    mark_job_failed!(deletion_event)
    raise
  end

  private

  def mark_job_started!(deletion_event)
    return unless deletion_event

    deletion_event.update!(
      status: :started,
      job_started_at: deletion_event.job_started_at || Time.current
    )
  end

  def mark_job_succeeded!(deletion_event)
    return unless deletion_event

    deletion_event.update!(
      status: :succeeded,
      job_succeeded_at: Time.current
    )
  end

  def mark_job_failed!(deletion_event)
    return unless deletion_event

    deletion_event.update!(
      status: :failed,
      job_failed_at: Time.current
    )
  end
end
