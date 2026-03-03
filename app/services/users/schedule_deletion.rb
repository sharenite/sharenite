# frozen_string_literal: true

module Users
  class ScheduleDeletion
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      enqueued = false

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
          enqueued = true
        end
      end

      UserDeletionJob.perform_later(user.id) if enqueued
      enqueued
    end

    private

    attr_reader :user
  end
end
