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
          Karafka.producer.produce_async(
            topic: "library.sync",
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
          Karafka.producer.produce_async(
            topic: "library.sync",
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
          Karafka.producer.produce_async(
            topic: "library.sync",
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
          Karafka.producer.produce_async(
            topic: "library.sync",
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
