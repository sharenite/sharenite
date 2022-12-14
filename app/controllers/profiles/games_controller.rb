# frozen_string_literal: true

# Games controller
module Profiles
  # Profiles games controller
  class GamesController < BaseController
    before_action :game, only: %i[show edit update destroy]

    def index
      set_games
      set_sync_job

      if turbo_frame_request?
        render partial: "games", locals: { games: @games }
      else
        render :index
      end
    end

    def show
    end

    def edit
    end

    def update
    end

    def destroy
    end

    private

    def set_sync_job
      @sync_job = @profile.user.sync_jobs.active&.first
    end

    def game
      @game = @profile.user.games.find_by(id: params[:id])
      @game ||= redirect_to_games_with_notice # defined in app controller
    end

    def set_games
      @games = (params[:query].present? ? @profile.user.games.filter_by_name(params[:query]) : @profile.user.games).order_by_last_activity
      @games_count = @games.count
      @games = @games.page params[:page]
    end

    def game_params
      params.require(:game).permit(:name, :user_id)
    end

    def redirect_to_games_with_notice
      # rubocop:disable Rails/I18nLocaleTexts
      flash[:notice] = "Game not found."
      # rubocop:enable all
      redirect_to profile_games_path
    end
  end
end
