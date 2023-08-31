# frozen_string_literal: true

# Job that performs call to get game from IGDB by id
class IgdbMatchGame
  def initialize(id)
    @game = Game.find(id)
  end

  def call
    match_game
  end

  def match_game
    igdb_cache = IgdbCache.find_by(name: @game.name)
    @game.update(igdb_cache:)

    igdb_cache.present?
    
    # TODO: call IGDB
  end
end