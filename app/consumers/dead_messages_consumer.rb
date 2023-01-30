# frozen_string_literal: true

# Example consumer that prints messages payloads
class DeadMessagesConsumer < ApplicationConsumer
  def variables(payload)
    @sync_job = SyncJob.find(payload["job_id"])
  end

  def consume
    messages.each do |message|
      variables(message.payload)
      finished_processing_at = Time.current
      @sync_job.update(finished_processing_at:, processing_time: finished_processing_at - @sync_job.started_processing_at)
      @sync_job.status_dead!
      # rubocop:disable Style/GlobalVars
      $redis.expire("syncjob:#{@sync_job.id}", 2_678_400)
      # rubocop:enable Style/GlobalVars
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
