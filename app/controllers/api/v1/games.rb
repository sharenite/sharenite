# frozen_string_literal: true

module API
  module V1
    # Games API endpoint
    # rubocop:disable Metrics/ClassLength
    class Games < Grape::API
      include API::V1::Defaults

      MAX_SYNCJOB_PAYLOAD_BYTES = ENV.fetch("SYNCJOB_MAX_PAYLOAD_BYTES", 5.megabytes).to_i
      MAX_SYNCJOB_GAMES_PER_JOB = ENV.fetch("SYNCJOB_MAX_GAMES_PER_JOB", 1_000).to_i

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
          chunked_games = chunk_sync_payload(type, games)
          total_chunks = chunked_games.size
          chunked_games.each_with_index do |chunk_games, chunk_index|
            enqueue_chunk_with_recovery(
              chunk_games:,
              metadata: {
                type:,
                base_job_name:,
                total_chunks:,
                chunk_index:
              }
            )
          end
        end

        def chunk_sync_payload(type, games)
          payload_json = games.to_json
          payload_size = payload_json.bytesize

          Rails.logger.debug { "[syncjob] type=#{type} user_id=#{current_user.id} payload_size_mb=#{(payload_size.to_f / 1024 / 1024).round(2)}" }

          return [games] if payload_size <= MAX_SYNCJOB_PAYLOAD_BYTES
          if type == "full"
            error!(
              "Full library sync payload exceeds #{MAX_SYNCJOB_PAYLOAD_BYTES} bytes. Please reduce sync payload size or increase server limit.",
              413
            )
          end

          chunk_by_count_and_bytes(type, games)
        end

        def sync_type_for_chunk(type, chunk_index)
          return type unless type == "full" && chunk_index.positive?

          "partial"
        end

        def sync_job_name(base_job_name, total_chunks, chunk_index)
          return base_job_name if total_chunks <= 1

          "#{base_job_name}(chunk #{chunk_index + 1}/#{total_chunks})"
        end

        def enqueue_single_sync_job!(type:, chunk_games:, metadata:)
          payload_json = chunk_games.to_json
          job = create_sync_job(payload_size: payload_json.bytesize, **metadata)

          persist_sync_payload(job, payload_json)
          publish_sync_job(job, type)
          job
        end

        def create_sync_job(base_job_name:, total_chunks:, chunk_index:, payload_size:)
          current_user.sync_jobs.create!(
            name: sync_job_name(base_job_name, total_chunks, chunk_index),
            payload_size_bytes: payload_size,
            payload_chunks: total_chunks,
            payload_chunk_index: chunk_index
          )
        end

        def persist_sync_payload(job, payload_json)
          # rubocop:disable Style/GlobalVars
          $redis.set("syncjob:#{job.id}", payload_json)
          # rubocop:enable Style/GlobalVars
        end

        def publish_sync_job(job, type)
          Karafka.producer.produce_sync(
            topic: "library.sync",
            payload: { type:, current_user_id: current_user.id, job_id: job.id }.to_json,
            key: current_user.id,
            partition_key: current_user.id
          )
        end

        def enqueue_chunk_with_recovery(chunk_games:, metadata:)
          job = enqueue_single_sync_job!(
            type: sync_type_for_chunk(metadata[:type], metadata[:chunk_index]),
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

        def chunk_by_count_and_bytes(type, games)
          chunks = []
          current_chunk = []
          current_chunk_bytes = 2 # JSON array brackets: []
          games.each do |game|
            game_json = game.to_json
            game_bytes = json_entry_size(current_chunk, game_json)
            current_chunk, current_chunk_bytes = roll_chunk_if_needed(chunks, current_chunk, current_chunk_bytes, game_bytes)
            validate_single_game_payload_size!(type, game_json)
            current_chunk << game
            current_chunk_bytes += game_bytes
          end
          chunks << current_chunk if current_chunk.any?
          chunks
        end

        def roll_chunk_if_needed(chunks, current_chunk, current_chunk_bytes, game_bytes)
          return [current_chunk, current_chunk_bytes] unless current_chunk.any? && chunk_limit_reached?(current_chunk, current_chunk_bytes, game_bytes)

          chunks << current_chunk
          [[], 2]
        end

        def chunk_limit_reached?(chunk, chunk_bytes, next_game_bytes)
          chunk.size >= MAX_SYNCJOB_GAMES_PER_JOB || (chunk_bytes + next_game_bytes > MAX_SYNCJOB_PAYLOAD_BYTES)
        end

        def json_entry_size(current_chunk, game_json)
          game_json.bytesize + (current_chunk.empty? ? 0 : 1) # comma separator
        end

        def validate_single_game_payload_size!(type, game_json)
          return unless game_json.bytesize + 2 > MAX_SYNCJOB_PAYLOAD_BYTES

          error!("A single game payload is too large for #{type} sync (#{MAX_SYNCJOB_PAYLOAD_BYTES} bytes limit).", 413)
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
