# frozen_string_literal: true

module API
  module V1
    # Games API endpoint
    # rubocop:disable Metrics/ClassLength
    class Games < Grape::API
      include API::V1::Defaults

      SYNCJOB_CHUNK_GAMES_PER_JOB = ENV.fetch("SYNCJOB_CHUNK_GAMES_PER_JOB", ENV.fetch("SYNCJOB_MAX_GAMES_PER_JOB", 1_000)).to_i
      FULL_SYNC_IDS_REDIS_TTL = 24.hours

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
          $redis.set("syncjob:#{job.id}", params[:game].to_json)
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
          sync_batch_id = prepare_full_sync_batch_id(type, games)
          chunked_games = chunk_sync_payload(type, games)
          total_chunks = chunked_games.size
          chunked_games.each_with_index do |chunk_games, chunk_index|
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

        def prepare_full_sync_batch_id(type, games)
          return nil unless type == "full"

          sync_batch_id = SecureRandom.uuid
          persist_full_sync_ids(sync_batch_id, games)
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
          $redis.set("syncjob:#{job.id}", payload_json)
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
            metadata: {
              base_job_name: metadata[:base_job_name],
              total_chunks: metadata[:total_chunks],
              chunk_index: metadata[:chunk_index]
            }
          )
        rescue StandardError => e
          job&.update(status: :failed, error_message: e.full_message(highlight: false))
          raise
        end

      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
