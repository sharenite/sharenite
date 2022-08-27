# frozen_string_literal: true

# Games controller
class GamesController < InheritedResources::Base
  def index
    @games = current_user.games.order(last_activity: :desc)
  end

  private

  def game_params
    params.require(:game).permit(:name, :user_id)
  end
end
