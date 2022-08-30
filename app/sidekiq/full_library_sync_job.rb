# frozen_string_literal: true

# Job that performs a full library sync asynchornously
class FullLibrarySyncJob
  include Sidekiq::Job

  def variables(args)
    @games = args[0]
    @user = User.find(args[1])
    @sync_job = SyncJob.find(args[2])
  end 
  
  def perform(*args)
    variables(args)
    start_job
    synchronise_games
    finish_job
  end

  private

  def start_job
    @sync_job.status_running!
  end

  def finish_job
    @sync_job.status_finished!
  end

  def synchronise_games
    @user.games.delete_all
    fill_in_the_blanks
          
    # rubocop:disable Rails/SkipsModelValidations
    @user.games.insert_all(@games)
    # rubocop:enable all
  end

  # rubocop:disable all
  def fill_in_the_blanks
    @games.map do |game|
      game['added'] = nil unless game.key?('added')
      game['community_score'] = nil unless game.key?('community_score')
      game['critic_score'] = nil unless game.key?('critic_score')
      game['description'] = nil unless game.key?('description')
      game['favorite'] = nil unless game.key?('favorite')
      game['game_id'] = nil unless game.key?('game_id')
      game['game_started_script'] = nil unless game.key?('game_started_script')
      game['hidden'] = nil unless game.key?('hidden')
      game['include_library_plugin_action'] = nil unless game.key?('include_library_plugin_action')
      game['install_directory'] = nil unless game.key?('install_directory')
      game['is_custom_game'] = nil unless game.key?('is_custom_game')
      game['is_installed'] = nil unless game.key?('is_installed')
      game['is_installing'] = nil unless game.key?('is_installing')
      game['is_launching'] = nil unless game.key?('is_launching')
      game['is_running'] = nil unless game.key?('is_running')
      game['is_uninstalling'] = nil unless game.key?('is_uninstalling')
      game['last_activity'] = nil unless game.key?('last_activity')
      game['manual'] = nil unless game.key?('manual')
      game['modified'] = nil unless game.key?('modified')
      game['notes'] = nil unless game.key?('notes')
      game['play_count'] = nil unless game.key?('play_count')
      game['playnite_id'] = nil unless game.key?('playnite_id')
      game['playtime'] = nil unless game.key?('playtime')
      game['plugin_id'] = nil unless game.key?('plugin_id')
      game['post_script'] = nil unless game.key?('post_script')
      game['pre_script'] = nil unless game.key?('pre_script')
      game['release_date'] = nil unless game.key?('release_date')
      game['sorting_name'] = nil unless game.key?('sorting_name')
      game['use_global_game_started_script'] = nil unless game.key?('use_global_game_started_script')
      game['use_global_post_script'] = nil unless game.key?('use_global_post_script')
      game['use_global_pre_script'] = nil unless game.key?('use_global_pre_script')
      game['user_score'] = nil unless game.key?('user_score')
      game['version'] = nil unless game.key?('version')
      game
    end
  end
  # rubocop:enable all
end
