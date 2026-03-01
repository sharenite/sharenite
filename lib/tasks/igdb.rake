# frozen_string_literal: true

namespace :igdb do
  desc "Match games created yesterday against IGDB cache"
  task match_yesterday: :environment do
    start_date = (Date.current - 1).to_s
    IgdbMatchGames.new(start_date).call
  end

  desc "Match games against IGDB cache with optional date range"
  task :match_games, [:start_date, :end_date] => :environment do |_t, args|
    IgdbMatchGames.new(args[:start_date], args[:end_date]).call
  end
end
