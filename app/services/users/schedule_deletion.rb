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
      return if user.deleting?

      User.transaction do
        user.lock!
        return if user.deleting?

        user.update!(
          deleting: true,
          deletion_requested_at: Time.current,
          email: user.deletion_placeholder_email,
          unconfirmed_email: nil,
          reset_password_token: nil,
          confirmation_token: nil
        )
      end

      UserDeletionJob.perform_later(user.id)
    end

    private

    attr_reader :user
  end
end
