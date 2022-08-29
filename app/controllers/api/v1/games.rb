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
            optional :added, type: DateTime, default: nil
            optional :community_score, type: Integer, default: nil
            optional :critic_score, type: Integer, default: nil
            optional :description, type: String, default: nil
            optional :favorite, type: Boolean, default: nil
            optional :game_id, type: String, default: nil
            optional :game_started_script, type: String, default: nil
            optional :hidden, type: Boolean, default: nil
            optional :include_library_plugin_action, type: Boolean, default: nil
            optional :install_directory, type: String, default: nil
            optional :is_custom_game, type: Boolean, default: nil
            optional :is_installed, type: Boolean, default: nil
            optional :is_installing, type: Boolean, default: nil
            optional :is_launching, type: Boolean, default: nil
            optional :is_running, type: Boolean, default: nil
            optional :is_uninstalling, type: Boolean, default: nil
            optional :last_activity, type: DateTime, default: nil
            optional :manual, type: String, default: nil
            optional :modified, type: DateTime, default: nil
            optional :notes, type: String, default: nil
            optional :play_count, type: Integer, default: nil
            optional :playtime, type: Integer, default: nil
            optional :plugin_id, type: String, default: nil
            optional :post_script, type: String, default: nil
            optional :pre_script, type: String, default: nil
            optional :release_date, type: Date, default: nil
            optional :sorting_name, type: String, default: nil
            optional :use_global_game_started_script, type: Boolean, default: nil
            optional :use_global_post_script, type: Boolean, default: nil
            optional :use_global_pre_script, type: Boolean, default: nil
            optional :user_score, type: Integer, default: nil
            optional :version, type: String, default: nil
          end
        end
        post "" do
          current_user.games.delete_all
          
          # rubocop:disable Rails/SkipsModelValidations
          current_user.games.insert_all(params[:games])
          # rubocop:enable all
          
          status 201
        end
      end
    end
  end
end
