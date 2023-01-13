# frozen_string_literal: true

# Example consumer that prints messages payloads
class LibrarySyncConsumer < ApplicationConsumer
  def variables(payload)
    @games = payload["games"]
    @user = User.find(payload["current_user_id"])
    @sync_job = SyncJob.find(payload["job_id"])
    @type = payload["type"]
  end

  # rubocop:disable Metrics/MethodLength
  def consume
    # rubocop:disable Metrics/BlockLength
    messages.each do |message|
      variables(message.payload)
      begin
        @sync_job.status_running!
        case @type
        when "full"
          FullLibrarySyncService.new(@games, @user, @sync_job).call
        when "partial"
          PartialLibrarySyncService.new(@games, @user, @sync_job).call
        when "delete"
          DeleteGamesSyncService.new(@games, @user, @sync_job).call
        when "single"
          raise "Method not implemented, check back later"
        end
      rescue StandardError => e
        @sync_job.status_failed!
        raise e
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
  # rubocop:enable Metrics/MethodLength

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
