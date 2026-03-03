# frozen_string_literal: true

module API
  module V1
    # Games API endpoint
    # rubocop:disable Metrics/ClassLength
    class Games < Grape::API
      include API::V1::Defaults

      SYNCJOB_CHUNK_GAMES_PER_JOB = ENV.fetch("SYNCJOB_CHUNK_GAMES_PER_JOB", ENV.fetch("SYNCJOB_MAX_GAMES_PER_JOB", 1_000)).to_i
      SYNCJOB_PAYLOAD_REDIS_TTL = 24.hours
      FULL_SYNC_IDS_REDIS_TTL = 24.hours
      SYNC_BATCH_STATUS_REDIS_TTL = 24.hours

      resource :games do
        desc "Return all games"
        get "" do
          current_user.games
        end

        desc "Register games"
        post "" do
          error! "Incorrect parameters, check for plugin updates" if params.dig("games", 0, "id").nil?
          enqueue_sync_jobs!(type: "full", base_job_name: "FullLibrarySyncJob", games: params[:games])
          GC.start
          status 202
        end

        desc "Update games"
        put "" do
          error! "Incorrect parameters, check for plugin updates" if params.dig("games", 0, "id").nil?
          enqueue_sync_jobs!(type: "partial", base_job_name: "PartialLibrarySyncJob", games: params[:games])
          GC.start
          status 202
        end

        desc "Delete games"
        put "delete" do
          error! "Incorrect parameters, check for plugin updates" if params.dig("games", 0, "id").nil?
          enqueue_sync_jobs!(type: "delete", base_job_name: "DeleteGamesSyncJob", games: params[:games])
          GC.start
          status 202
        end

        desc "Update game"
        put ":id" do
          error! "Method not implemented, check back later"
          job = current_user.sync_jobs.create(name: "GameSyncJob")
          # rubocop:disable Style/GlobalVars
          $redis.set("syncjob:#{job.id}", params[:game].to_json, ex: SYNCJOB_PAYLOAD_REDIS_TTL.to_i)
          # rubocop:enable Style/GlobalVars
          Karafka.producer.produce_sync(
            topic: "library.sync",
            payload: { type: "single", id: params[:id], current_user_id: current_user.id, job_id: job.id }.to_json,
            key: current_user.id,
            partition_key: current_user.id
          )
          GC.start
          status 202
        end
      end

      helpers do
        def enqueue_sync_jobs!(type:, base_job_name:, games:)
          sync_batch_id = prepare_sync_batch!(type, games)
          chunked_games = chunk_sync_payload(type, games)
          enqueued_jobs = enqueue_chunked_jobs(type, base_job_name, sync_batch_id, chunked_games)
          mark_sync_batch_status(sync_batch_id, "ready")
        rescue StandardError => e
          handle_chunk_enqueue_failure(sync_batch_id, enqueued_jobs, e)
          raise
        end

        def enqueue_chunked_jobs(type, base_job_name, sync_batch_id, chunked_games)
          total_chunks = chunked_games.size
          chunked_games.each_with_index.map do |chunk_games, chunk_index|
            enqueue_chunk_with_recovery(
              chunk_games:,
              metadata: {
                type:,
                base_job_name:,
                total_chunks:,
                chunk_index:,
                sync_batch_id:
              }
            )
          end
        end

        def handle_chunk_enqueue_failure(sync_batch_id, enqueued_jobs, error)
          return if sync_batch_id.blank?

          mark_sync_batch_status(sync_batch_id, "failed")
          mark_enqueued_jobs_failed(enqueued_jobs, error)
          clear_full_sync_ids(sync_batch_id)
        end

        def prepare_sync_batch!(type, games)
          sync_batch_id = SecureRandom.uuid
          mark_sync_batch_status(sync_batch_id, "publishing")
          persist_full_sync_ids(sync_batch_id, games) if type == "full"
          sync_batch_id
        end

        def persist_full_sync_ids(sync_batch_id, games)
          ids = games.filter_map { |game| game["id"] }.uniq
          # rubocop:disable Style/GlobalVars
          $redis.set(full_sync_ids_redis_key(sync_batch_id), ids.to_json, ex: FULL_SYNC_IDS_REDIS_TTL.to_i)
          # rubocop:enable Style/GlobalVars
        end

        def full_sync_ids_redis_key(sync_batch_id)
          "full_sync_ids:#{sync_batch_id}"
        end

        def sync_batch_status_redis_key(sync_batch_id)
          "sync_batch_status:#{sync_batch_id}"
        end

        def mark_sync_batch_status(sync_batch_id, status)
          # rubocop:disable Style/GlobalVars
          $redis.set(sync_batch_status_redis_key(sync_batch_id), status, ex: SYNC_BATCH_STATUS_REDIS_TTL.to_i)
          # rubocop:enable Style/GlobalVars
        end

        def chunk_sync_payload(type, games)
          Rails.logger.debug { "[syncjob] type=#{type} user_id=#{current_user.id} games_count=#{games.size}" }
          games.each_slice(SYNCJOB_CHUNK_GAMES_PER_JOB).to_a
        rescue ArgumentError
          [games]
        end

        def sync_job_name(base_job_name, total_chunks, chunk_index)
          return base_job_name if total_chunks <= 1

          "#{base_job_name}(chunk #{chunk_index + 1}/#{total_chunks})"
        end

        def enqueue_single_sync_job!(type:, chunk_games:, metadata:)
          payload_json = chunk_games.to_json
          job = create_sync_job(metadata:, payload_size: payload_json.bytesize)

          persist_sync_payload(job, payload_json)
          publish_sync_job(job, type, metadata)
          job
        end

        def create_sync_job(metadata:, payload_size:)
          current_user.sync_jobs.create!(
            name: sync_job_name(metadata[:base_job_name], metadata[:total_chunks], metadata[:chunk_index]),
            payload_size_bytes: payload_size,
            payload_chunks: metadata[:total_chunks],
            payload_chunk_index: metadata[:chunk_index]
          )
        end

        def persist_sync_payload(job, payload_json)
          # rubocop:disable Style/GlobalVars
          $redis.set("syncjob:#{job.id}", payload_json, ex: SYNCJOB_PAYLOAD_REDIS_TTL.to_i)
          # rubocop:enable Style/GlobalVars
        end

        def publish_sync_job(job, type, metadata)
          Karafka.producer.produce_sync(
            topic: "library.sync",
            payload: {
              type:,
              current_user_id: current_user.id,
              job_id: job.id,
              total_chunks: metadata[:total_chunks],
              chunk_index: metadata[:chunk_index],
              sync_batch_id: metadata[:sync_batch_id]
            }.to_json,
            key: current_user.id,
            partition_key: current_user.id
          )
        end

        def enqueue_chunk_with_recovery(chunk_games:, metadata:)
          job = enqueue_single_sync_job!(
            type: metadata[:type],
            chunk_games:,
            metadata:
          )
        rescue StandardError => e
          job&.update(status: :failed, error_message: e.full_message(highlight: false))
          raise
        end

        def mark_enqueued_jobs_failed(enqueued_jobs, error)
          return if enqueued_jobs.blank?

          enqueued_jobs.compact.each do |job|
            job.update(status: :failed, error_message: "Chunk enqueue failed: #{error.message}")
          end
        end

        def clear_full_sync_ids(sync_batch_id)
          # rubocop:disable Style/GlobalVars
          $redis.del(full_sync_ids_redis_key(sync_batch_id))
          # rubocop:enable Style/GlobalVars
        end

      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
