# frozen_string_literal: true

class UserDeletionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 10

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.deleting?

    user.destroy!
  end
end
