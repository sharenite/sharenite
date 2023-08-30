# frozen_string_literal: true

# Games controller
module Profiles
  module Playlists
    # Profiles base controller
    class BaseController < ::Profiles::BaseController
      before_action :check_current_user_playlist, only: %i[new create edit update destroy]
      before_action :check_general_access_playlist, only: %i[index show]

      def index
      end

      def show
      end

      def new
      end

      def edit
      end

      def create
      end

      def update
      end

      def destroy
      end

      private

      def set_playlist
        @playlist = Playlist.find(params[:playlist_id])
      end

      def check_current_user_playlist
        set_playlist
        redirect_to_playlists_with_notice unless current_user.playlists.exists?(@playlist.id)
      rescue ActiveRecord::RecordNotFound
        redirect_to_playlists_with_notice
      end

      def check_general_access_playlist
        set_playlist
        check_playlist
      rescue ActiveRecord::RecordNotFound
        redirect_to_playlists_with_notice
      end

      def check_playlist
        redirect_to_playlists_with_notice if @playlist.nil? || 
          (!playlist_own? && 
          !playlist_public?)
      end

      def check_friendly_playlist
        redirect_to_playlists_with_notice if @playlist.nil? || 
          !playlist_public?
      end

      def playlist_own?
        current_user.playlists.exists?(@playlist)
      end

      def playlist_public?
        @playlist.public == true
      end

      def redirect_to_playlists_with_notice
        # rubocop:disable Rails/I18nLocaleTexts
        flash[:notice] = "Playlist not found or set to private."
        # rubocop:enable all
        redirect_to profile_playlists_path
      end
    end
  end
end