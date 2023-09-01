# frozen_string_literal: true

# Job that performs call to get game from IGDB by id
class IgdbMatchGames
  def initialize(start_date = nil, end_date = nil)
    @start_date = Date.parse(start_date) if start_date.present?
    @end_date = Date.parse(end_date) if end_date.present?
    @matched = 0
    @unmatched = 0
  end

  def call
    match_games
    print_results
    nil
  end

  # rubocop:disable Metrics/AbcSize 
  # rubocop:disable Metrics/MethodLength 
  def match_games
    games = Game.where(igdb_cache: nil)
    games = games.where("created_at >= ?", @start_date) if @start_date.present?
    games = games.where("created_at <= ?", @end_date) if @end_date.present?
    bar = RakeProgressbar.new(games.count)
    igdb_caches = IgdbCache.all.select(:id, :name)
    games.each do |game|
      igdb_cache = igdb_caches.detect {|ic| ic.name == game.name }
      if igdb_cache.present?
        game.update(igdb_cache:)
        @matched += 1
      else
        @unmatched += 1
      end
      bar.inc
    end
    bar.finished
  end
  # rubocop:enable all

  def print_results
    Rails.logger.debug { "Matched games: #{@matched}" }
    Rails.logger.debug { "Unmatched games: #{@unmatched}" }
  end
end