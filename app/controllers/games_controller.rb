# frozen_string_literal: true

# Games controller
class GamesController < InheritedResources::Base
  def index
    set_games

    logger.debug 'turbo_frame_request?'
    logger.debug turbo_frame_request?

    if turbo_frame_request?
      render partial: "games", locals: { games: @games }
    else
      render :index
    end
  
  end

  private

  def set_games
    @games = if params[:query].present?
      current_user.games.filter_by_name(params[:query]).order_by_last_activity
    else
      current_user.games.order_by_last_activity
             end
  end

  def game_params
    params.require(:game).permit(:name, :user_id)
  end
end
