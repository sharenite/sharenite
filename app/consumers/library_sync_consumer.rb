# frozen_string_literal: true

# Example consumer that prints messages payloads
# rubocop:disable Metrics/ClassLength
class LibrarySyncConsumer < ApplicationConsumer
  MissingSyncPayloadError = Class.new(StandardError)
  InvalidSyncPayloadError = Class.new(StandardError)
  SYNC_BATCH_READY_TIMEOUT_SECONDS = 10
  SYNC_BATCH_READY_POLL_SECONDS = 0.2

  def variables(payload)
    assign_sync_context(payload)
    assign_payload_metadata(payload)
    ensure_sync_batch_ready!
    load_sync_payload!
  rescue JSON::ParserError => e
    raise InvalidSyncPayloadError, "Invalid Redis payload for syncjob:#{@sync_job.id}: #{e.message}"
  end

  def start_processing
    if @sync_job.started_processing_at.nil?
      started_processing_at = Time.current
      @sync_job.update(started_processing_at:, waiting_time: started_processing_at - @sync_job.created_at)
    end
    @sync_job.status_running!
  end

  def do_processing
    sync_service_for_type.call
  end

  def end_processing
    finished_processing_at = Time.current
    @sync_job.update(finished_processing_at:, processing_time: finished_processing_at - @sync_job.started_processing_at)
    @sync_job.status_finished!
    expire_sync_payload
  end

  def consume
    messages.each do |message|
      variables(message.payload)
      start_processing
      do_processing
      end_processing
    rescue StandardError => e
      mark_sync_job_failed(e)
      Appsignal.set_error(e)
      raise
    end
  end

  def mark_sync_job_failed(error)
    return if @sync_job.nil?

    finished_processing_at = Time.current
    attributes = {
      finished_processing_at:,
      error_message: error.full_message(highlight: false)
    }

    if @sync_job.started_processing_at.nil?
      attributes[:waiting_time] = finished_processing_at - @sync_job.created_at
      attributes[:processing_time] = 0
    else
      attributes[:processing_time] = finished_processing_at - @sync_job.started_processing_at
    end

    @sync_job.update(attributes)
    @sync_job.status_failed!
    expire_sync_payload
  end

  def expire_sync_payload
    # rubocop:disable Style/GlobalVars
    $redis.expire("syncjob:#{@sync_job.id}", 1)
    # rubocop:enable Style/GlobalVars
  end

  def assign_sync_context(payload)
    @user = User.find(payload["current_user_id"])
    @sync_job = SyncJob.find(payload["job_id"])
  end

  def load_sync_payload!
    # rubocop:disable Style/GlobalVars
    raw_games = $redis.get("syncjob:#{@sync_job.id}")
    # rubocop:enable Style/GlobalVars
    raise MissingSyncPayloadError, "Missing Redis payload for syncjob:#{@sync_job.id}" if raw_games.blank?

    @games = JSON.parse(raw_games)
  end

  def assign_payload_metadata(payload)
    @type = payload["type"]
    @sync_batch_id = payload["sync_batch_id"]
    @chunk_index = payload["chunk_index"]
    @total_chunks = payload["total_chunks"]
  end

  def sync_service_for_type
    case @type
    when "full"
      full_sync_service
    when "partial"
      PartialLibrarySyncService.new(@games, @user, @sync_job)
    when "delete"
      DeleteGamesSyncService.new(@games, @user, @sync_job)
    when "single"
      raise "Method not implemented, check back later"
    end
  end

  def ensure_sync_batch_ready!
    return if @sync_batch_id.blank?

    deadline = Time.current + SYNC_BATCH_READY_TIMEOUT_SECONDS
    loop do
      status = sync_batch_status
      return if status.blank? || status == "ready"
      raise InvalidSyncPayloadError, "Sync batch #{@sync_batch_id} failed during enqueue." if status == "failed"
      break if Time.current >= deadline

      sleep(SYNC_BATCH_READY_POLL_SECONDS)
    end

    raise InvalidSyncPayloadError, "Sync batch #{@sync_batch_id} was not marked ready before processing."
  end

  def sync_batch_status
    # rubocop:disable Style/GlobalVars
    $redis.get(sync_batch_status_redis_key(@sync_batch_id))
    # rubocop:enable Style/GlobalVars
  end

  def sync_batch_status_redis_key(sync_batch_id)
    "sync_batch_status:#{sync_batch_id}"
  end

  def full_sync_service
    FullLibrarySyncService.new(
      @games,
      @user,
      @sync_job,
      sync_batch_id: @sync_batch_id,
      chunk_index: @chunk_index,
      total_chunks: @total_chunks
    )
  end

  # FOR TESTING FIFO PER USER
  # def consume
  #   messages.each do |message|
  #     variables(message.payload)
  #     begin
  #       @sync_job.status_running!
  #       case @type
  #       when "full"
  #         puts "full cowboy #{@games.first["id"]} #{message.payload["current_user_id"]}"
  #         sleep(rand(0..2))
  #         puts "full beebop #{@games.first["id"]} #{message.payload["current_user_id"]}"
  #       when "partial"
  #         puts "partial cowboy #{@games.first["id"]} #{message.payload["current_user_id"]}"
  #         sleep(rand(4..6))
  #         puts "partial beebop #{@games.first["id"]} #{message.payload["current_user_id"]}"
  #       when "delete"
  #         puts "delete cowboy #{@games.first["id"]} #{message.payload["current_user_id"]}"
  #         sleep(rand(4..6))
  #         puts "delete beebop #{@games.first["id"]} #{message.payload["current_user_id"]}"
  #       when "single"
  #         raise "Method not implemented, check back later"
  #       end
  #     rescue StandardError => e
  #       @sync_job.status_failed!
  #       raise e
  #     end
  #   end
  # end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
# rubocop:enable Metrics/ClassLength
