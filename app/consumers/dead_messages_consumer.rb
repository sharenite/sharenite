# frozen_string_literal: true

# Example consumer that prints messages payloads
class DeadMessagesConsumer < ApplicationConsumer
  DEAD_SYNCJOB_PAYLOAD_TTL = 2_678_400

  def variables(payload)
    @payload = payload
    @sync_job = SyncJob.find_by(id: payload&.[]("job_id"))
  end

  def consume
    messages.each do |message|
      variables(message.payload)
      next if @payload.blank? || @sync_job.nil?

      @sync_job.update(dead_timing_attributes(@sync_job))
      @sync_job.status_dead!
      # rubocop:disable Style/GlobalVars
      $redis.expire("syncjob:#{@sync_job.id}", DEAD_SYNCJOB_PAYLOAD_TTL)
      $redis.set("syncjob_dead_payload:#{@sync_job.id}", @payload.to_json, ex: DEAD_SYNCJOB_PAYLOAD_TTL)
      # rubocop:enable Style/GlobalVars
    end
  end

  private

  def dead_timing_attributes(sync_job)
    finished_processing_at = Time.current
    return dead_timing_for_never_started(sync_job, finished_processing_at) if sync_job.started_processing_at.nil?

    {
      finished_processing_at:,
      processing_time: finished_processing_at - sync_job.started_processing_at
    }
  end

  def dead_timing_for_never_started(sync_job, finished_processing_at)
    {
      started_processing_at: finished_processing_at,
      finished_processing_at:,
      waiting_time: finished_processing_at - sync_job.created_at,
      processing_time: 0
    }
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
