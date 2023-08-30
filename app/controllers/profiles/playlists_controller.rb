# frozen_string_literal: true

# Playlists controller
module Profiles
  # Profiles playlists controller
  class PlaylistsController < BaseController
    before_action :playlist, only: %i[show edit update destroy]

    def index
      set_playlists
    end

    def show
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
          format.turbo_stream { redirect_to profile_playlists_path(@profile, @playlist) }
        else
          format.turbo_stream { render turbo_stream: turbo_stream.replace("playlist_errors", partial: "playlist_errors") }
        end
      end
    end

    def update
      respond_to do |format|
        if @playlist.update(playlist_params)
          format.turbo_stream { redirect_to profile_playlists_path(@profile, @playlist) }
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

    def playlist_params
      params.require(:playlist).permit(:name, :public)
    end

    def redirect_to_playlists_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Playlist not found."
      # rubocop:enable all
      redirect_to profile_playlists_path
    end
  end
end