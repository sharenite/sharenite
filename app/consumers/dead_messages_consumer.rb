# frozen_string_literal: true

# Example consumer that prints messages payloads
class DeadMessagesConsumer < ApplicationConsumer
  def variables(payload)
    @sync_job = SyncJob.find(payload["job_id"])
  end

  def consume
    messages.each do |message|
      variables(message.payload)
      @sync_job.status_dead!
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
