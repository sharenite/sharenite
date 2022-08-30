# frozen_string_literal: true

# Games controller
class GamesController < InheritedResources::Base
  before_action :game, only: [:show, :edit, :update, :destroy]

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
    @sync_job = current_user.sync_jobs.active&.first
  end

  def game
    @game = current_user.games.find_by(id: params[:id])
    @game ||= invalid_url! # defined in app controller 
  end

  def set_games
    @games = if params[:query].present?
      current_user.games.filter_by_name(params[:query])
    else
      current_user.games
             end.order_by_last_activity
    @games_count = @games.count
    @games = @games.page params[:page]
  end

  def game_params
    params.require(:game).permit(:name, :user_id)
  end
end
