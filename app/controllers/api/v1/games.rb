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
          params[:games].each do |game|
            Game.create!(game.merge(user: current_user))
          end
          current_user.games.reload
        end
      end
    end
  end
end
