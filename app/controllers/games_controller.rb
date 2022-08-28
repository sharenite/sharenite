# frozen_string_literal: true

# Games controller
class GamesController < InheritedResources::Base
  def index
    @games = current_user.games.order_by_last_activity
  end

  # rubocop:disable Metrics/MethodLength
  def search
    set_games
    
    # rubocop:disable Metrics/BlockLength
    respond_to do |format|
      format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("games",
            partial: "games/games",
            locals: { games: @games })
          ]
      end
    end
  end
  # rubocop:enable all

  private

  def set_games
    @games = if params[:name_search].present?
      current_user.games.filter_by_name(params[:name_search]).order_by_last_activity
    else
      current_user.games.order_by_last_activity
             end
  end

  def game_params
    params.require(:game).permit(:name, :user_id)
  end
end
