# frozen_string_literal: true

module API
  module V1
    # Games API endpoint
    class Games < Grape::API
      include API::V1::Defaults
      resource :games do
        desc "Return all games"
        get "" do
          current_user.games
        end

        desc "Register games"
        post "" do
          error! "Incorrect parameters, check for plugin updates" if params.dig("games", 0, "id").nil?
          job = current_user.sync_jobs.create(name: "FullLibrarySyncJob")
          # 5 seconds delay for new jobs is needed to assure that any job rescheduled by sidekiq_unique runs first
          # FullLibrarySyncJob.perform_in(5.seconds, params[:games], current_user.id, job.id)
          Karafka.producer.produce_async(
            topic: "library_sync",
            payload: { type: "full", games: params[:games], current_user_id: current_user.id, job_id: job.id }.to_json,
            partition_key: current_user.id
          )
          GC.start
          status 202
        end

        desc "Update games"
        put "" do
          error! "Incorrect parameters, check for plugin updates" if params.dig("games", 0, "id").nil?
          job = current_user.sync_jobs.create(name: "PartialLibrarySyncJob")
          # 5 seconds delay for new jobs is needed to assure that any job rescheduled by sidekiq_unique runs first
          # PartialLibrarySyncJob.perform_in(5.seconds, params[:games], current_user.id, job.id)
          Karafka.producer.produce_async(
            topic: "library_sync",
            payload: { type: "partial", games: params[:games], current_user_id: current_user.id, job_id: job.id }.to_json,
            partition_key: current_user.id
          )
          GC.start
          status 202
        end

        desc "Delete games"
        put "delete" do
          error! "Incorrect parameters, check for plugin updates" if params.dig("games", 0, "id").nil?
          job = current_user.sync_jobs.create(name: "DeleteGamesSyncJob")
          # 5 seconds delay for new jobs is needed to assure that any job rescheduled by sidekiq_unique runs first
          # DeleteGamesSyncJob.perform_in(5.seconds, params[:games], current_user.id, job.id)
          Karafka.producer.produce_async(
            topic: "library_sync",
            payload: { type: "delete", games: params[:games], current_user_id: current_user.id, job_id: job.id }.to_json,
            partition_key: current_user.id
          )
          GC.start
          status 202
        end

        desc "Update game"
        put ":id" do
          error! "Method not implemented, check back later"
          job = current_user.sync_jobs.create(name: "GameSyncJob")
          # 5 seconds delay for new jobs is needed to assure that any job rescheduled by sidekiq_unique runs first
          # GameSyncJob.perform_in(5.seconds, params[:id], params[:game], current_user.id, job.id)
          Karafka.producer.produce_async(
            topic: "library_sync",
            payload: { type: "single", id: params[:id], game: params[:game], current_user_id: current_user.id, job_id: job.id }.to_json,
            partition_key: current_user.id
          )
          GC.start
          status 202
        end
      end
    end
  end
end
