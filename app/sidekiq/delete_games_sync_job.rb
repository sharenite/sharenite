# frozen_string_literal: true

# Job that performs a full library sync asynchornously
class DeleteGamesSyncJob
  include Sidekiq::Job

  def variables(args)
    @games = args[0]
    @user = User.find(args[1])
    @sync_job = SyncJob.find(args[2])
  end 
  
  def perform(*args)
    variables(args)
    start_job
    delete_games
    finish_job
  end

  private

  def start_job
    @sync_job.status_running!
  end

  def finish_job
    @sync_job.status_finished!
  end

  def delete_games
    @user.games.where(playnite_id: @games.map { |h| h['playnite_id'] }).delete_all
  end
end
