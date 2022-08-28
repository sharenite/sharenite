# frozen_string_literal: true

# Games controller
class GamesController < InheritedResources::Base
  def index
    set_games

    if turbo_frame_request?
      render partial: "games", locals: { games: @games }
    else
      render :index
    end
  
  end

  private

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
