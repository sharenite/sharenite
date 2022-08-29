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
        params do
          requires :games, type: Array do
            requires :name, type: String
            optional :added, type: DateTime
            optional :community_score, type: Integer
            optional :critic_score, type: Integer
            optional :description, type: String
            optional :favorite, type: Boolean
            optional :game_id, type: String
            optional :game_started_script, type: String
            optional :hidden, type: Boolean
            optional :include_library_plugin_action, type: Boolean
            optional :install_directory, type: String
            optional :is_custom_game, type: Boolean
            optional :is_installed, type: Boolean
            optional :is_installing, type: Boolean
            optional :is_launching, type: Boolean
            optional :is_running, type: Boolean
            optional :is_uninstalling, type: Boolean
            optional :last_activity, type: DateTime
            optional :manual, type: String
            optional :modified, type: DateTime
            optional :notes, type: String
            optional :play_count, type: Integer
            optional :playtime, type: Integer
            optional :plugin_id, type: String
            optional :post_script, type: String
            optional :pre_script, type: String
            optional :release_date, type: Date
            optional :sorting_name, type: String
            optional :use_global_game_started_script, type: Boolean
            optional :use_global_post_script, type: Boolean
            optional :use_global_pre_script, type: Boolean
            optional :user_score, type: Integer
            optional :version, type: String
          end
        end
        post "" do
          current_user.games.delete_all
          params[:games].map do |game|
            game['user_id'] = current_user.id
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
          # rubocop:disable Rails/SkipsModelValidations
          Game.insert_all(params[:games])
          # rubocop:enable all
          current_user.games.reload
        end
      end
    end
  end
end
