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
          job = current_user.sync_jobs.create(name: "FullLibrarySyncJob")
          FullLibrarySyncJob.perform_async(
            params[:games],
            current_user.id,
            job.id
          )
          GC.start
          status 202
        end

        desc "Update games"
        put "" do
          job = current_user.sync_jobs.create(name: "PartialLibrarySyncJob")
          PartialLibrarySyncJob.perform_async(
            params[:games],
            current_user.id,
            job.id
          )
          GC.start
          status 202
        end

        desc "Delete games"
        put "delete" do
          job = current_user.sync_jobs.create(name: "DeleteGamesSyncJob")
          DeleteGamesSyncJob.perform_async(
            params[:games],
            current_user.id,
            job.id
          )
          GC.start
          status 202
        end

        desc "Update game"
        put ":id" do
          job = current_user.sync_jobs.create(name: "GameSyncJob")
          GameSyncJob.perform_async(
            params[:id],
            params[:game],
            current_user.id,
            job.id
          )
          GC.start
          status 202
        end
      end
    end
  end
end
