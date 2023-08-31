# frozen_string_literal: true

# Job that performs call to get game from IGDB by id
class IgdbMatchGames
  def initialize(start_date = nil)
    @start_date = Date.parse(start_date) if start_date.present?
    @matched = 0
    @unmatched = 0
  end

  def call
    match_games
    print_results
    nil
  end

  def match_games
    games = Game.where(igdb_cache: nil)
    games = games.where("created_at > ?", @start_date) if @start_date.present?
    games.each do |game|
      if IgdbMatchGame.new(game.id).call
        @matched += 1
      else
        @unmatched += 1
      end
    end
  end

  def print_results
    Rails.logger.debug { "Matched games: #{@matched}" }
    Rails.logger.debug { "Unmatched games: #{@unmatched}" }
  end
end