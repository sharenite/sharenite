# frozen_string_literal: true

# Playlists controller
module Profiles
  # Profiles playlists controller
  class PlaylistsController < BaseController
    before_action :playlist, only: %i[show]

    def index
      set_playlists
    end

    def show
    end

    private

    def set_sync_jobs
      @sync_jobs = @profile.user.sync_jobs.active.order(:created_at) if !@current_user.nil? && @profile == @current_user.profile
    end

    def playlist
      @playlist = @profile.user.playlists.find_by(id: params[:id])
      @playlist ||= redirect_to_playlists_with_notice # defined in app controller
    end

    def set_playlists
      @playlists = @profile.user.playlists
      @playlists = @playlists.page params[:page]
    end

    def game_params
      params.require(:game).permit(:name, :user_id)
    end

    def redirect_to_playlists_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Playlist not found."
      # rubocop:enable all
      redirect_to profile_playlists_path
    end
  end
end