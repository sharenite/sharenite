# frozen_string_literal: true

# Job that performs a full library sync asynchornously
class DeleteGamesSyncService
  def initialize(games, user, sync_job)
    @games = games
    @user = user
    @sync_job = sync_job
  end

  def call
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
    @user.games.where(playnite_id: @games.pluck("id")).destroy_all
  end
end
