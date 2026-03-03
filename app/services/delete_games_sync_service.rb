# frozen_string_literal: true

# Job that performs a full library sync asynchornously
class DeleteGamesSyncService
  def initialize(games, user, sync_job)
    @games = games
    @user = user
    @sync_job = sync_job
  end

  def call
    delete_games
  end

  private

  def delete_games
    @user.games.where(playnite_id: @games.pluck("id")).destroy_all
  end
end
