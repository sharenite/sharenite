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
      if @sync_job.started_processing_at.nil?
        @sync_job.update(started_processing_at: finished_processing_at, finished_processing_at:, waiting_time: finished_processing_at - @sync_job.created_at, processing_time: 0)
      else
        @sync_job.update(finished_processing_at:, processing_time: finished_processing_at - @sync_job.started_processing_at)
      end
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
