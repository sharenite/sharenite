module API
  module V1
    class Games < Grape::API
      include API::V1::Defaults
      resource :games do
        desc "Return all games"
        get "" do
          current_user.games
        end

        desc "Register games"
        params do
          requires :games, type: Array do
            requires :name, type: String
          end
        end
        post "" do
          games = []
          params[:games].each do |game|
            current_user.games.destroy_all
            games << Game.create!(game.merge user: current_user)
          end
          games
        end
      end
    end
  end
end