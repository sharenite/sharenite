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
          job = current_user.sync_jobs.create(name: 'FullLibrarySyncJob')
          FullLibrarySyncJob.perform_async(params[:games], current_user.id, job.id)
          status 201
        end
      end
    end
  end
end
