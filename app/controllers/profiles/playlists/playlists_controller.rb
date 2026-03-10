# frozen_string_literal: true

# Playlists controller
module Profiles
  module Playlists
    # Profiles playlists controller
    class PlaylistsController < ::Profiles::BaseController
      include PlaylistAccess

      before_action :check_current_user_profile, only: %i[new create edit update destroy]
      before_action :check_playlist_library_access_profile, only: %i[index]
      before_action :playlist, only: %i[show edit update destroy]

      def index
        set_playlists
      end

      def show
        @owned_counts_by_igdb_cache_id = {}
        @owned_statuses_by_igdb_cache_id = {}
        set_playlist_overview
      end

      def new
        @playlist = @profile.user.playlists.new
      end

      def edit
      end

      def create
        @playlist = @profile.user.playlists.new(playlist_params)
        respond_to do |format|
          if @playlist.save
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_errors", partial: "playlist_errors") }
          end
        end
      end

      def update
        respond_to do |format|
          if @playlist.update(playlist_params)
            format.turbo_stream { redirect_to profile_playlist_path(@profile, @playlist) }
          else
            format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_errors", partial: "playlist_errors") }
          end
        end
      end

      def destroy
        @playlist.destroy!
        respond_to do |format|
          format.turbo_stream { redirect_to profile_playlists_path(@profile, @playlist) }
        end
      rescue ActiveRecord::RecordNotDestroyed => e
        flash[:error] = "errors that prevented deletion: #{e.record.errors.full_messages}}"
      end

      private

      def check_playlist_library_access_profile
        return if profile_own?
        return if @profile.playlists_visible_to?(current_user)

        redirect_to_profile_when_playlist_library_hidden
      end

      def playlist_params
        params.require(:playlist).permit(:name, :private_override)
      end

      def redirect_to_playlists_with_notice
        # rubocop:disable Rails/I18nLocaleTexts
        flash[:notice] = "Playlist not found."
        # rubocop:enable all
        redirect_to profile_playlists_path(@profile)
      end

      def redirect_to_profile_when_playlist_library_hidden
        # rubocop:disable Rails/I18nLocaleTexts
        redirect_to profile_path(@profile), notice: "This profile's playlists are private."
        # rubocop:enable Rails/I18nLocaleTexts
      end
    end
  end
end
