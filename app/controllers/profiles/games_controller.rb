# frozen_string_literal: true

# Games controller
module Profiles
  # Profiles games controller
  class GamesController < BaseController
    before_action :game, only: %i[show edit update destroy]

    def index
      set_games
      set_sync_jobs

      if turbo_frame_request?
        render partial: "games", locals: { games: @games }
      else
        render :index
      end
    end

    def show
    end

    def edit
      @igdb_cache = @game.igdb_cache || @game.build_igdb_cache
    end

    def update
      igdb_id = params[:game][:igdb_cache][:igdb_id]
      igdb_cache = nil
      igdb_cache = IgdbCache.get_by_igdb_id(igdb_id) if igdb_id.present?
    if @game.update(igdb_cache:)
      redirect_to profile_game_path(@profile, @game) 
    else
      format.turbo_stream { render turbo_stream: turbo_stream.replace("game_errors", partial: "game_errors") }
    end
    end

    def destroy
    end

    private

    def set_sync_jobs
      @sync_jobs = @profile.user.sync_jobs.active.order(:created_at) if !@current_user.nil? && @profile == @current_user.profile
    end

    def game
      @game = @profile.user.games.find_by(id: params[:id])
      @game ||= redirect_to_games_with_notice # defined in app controller
    end

    def filter_games
      @games = @games.filter_by_name(params[:query]) if params[:query].present?
      @games = @games.search(params[:search_query]) if params[:search_query].present?
    end

    def set_games
      @games = @profile.user.games
      filter_games
      @games = @games.order_by_last_activity
      @games_count = @games.count
      @games = @games.page params[:page]
    end

    def game_params
      params.require(:game).permit(igdb_cache: [:igdb_id])
    end

    def redirect_to_games_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Game not found."
      # rubocop:enable all
      redirect_to profile_games_path
    end
  end
end
