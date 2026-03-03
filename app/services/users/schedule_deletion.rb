# frozen_string_literal: true

module Users
  # Flags a user for deletion, anonymizes credentials, and enqueues async destroy.
  class ScheduleDeletion
    def self.call(user, scheduled_by_admin_user: nil)
      new(user, scheduled_by_admin_user:).call
    end

    def initialize(user, scheduled_by_admin_user:)
      @user = user
      @scheduled_by_admin_user = scheduled_by_admin_user
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def call
      enqueued = false
      deletion_event_id = nil

      # Keep user update + event creation atomic so job always has matching event context.
      # rubocop:disable Metrics/BlockLength
      User.transaction do
        user.lock!
        user.skip_reconfirmation! if user.respond_to?(:skip_reconfirmation!)

        if user.deleting?
          user.update!(
            email: user.deletion_placeholder_email,
            unconfirmed_email: nil,
            reset_password_token: nil,
            confirmation_token: nil
          )
        else
          user.update!(
            deleting: true,
            deletion_requested_at: Time.current,
            email: user.deletion_placeholder_email,
            unconfirmed_email: nil,
            reset_password_token: nil,
            confirmation_token: nil
          )
          deletion_event = UserDeletionEvent.create!(
            requested_at: Time.current,
            status: :requested,
            scheduled_by_admin: scheduled_by_admin_user.present?,
            scheduled_by_admin_email: scheduled_by_admin_user&.email,
            scheduled_by_admin_user:
          )
          deletion_event_id = deletion_event.id
          enqueued = true
        end
      end
      # rubocop:enable Metrics/BlockLength

      UserDeletionJob.perform_later(user.id, deletion_event_id) if enqueued
      enqueued
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    attr_reader :user, :scheduled_by_admin_user
  end
end
