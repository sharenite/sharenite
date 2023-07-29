# frozen_string_literal: true
# rubocop:disable Style/GlobalVars
$redis = Redis.new(host: "sharenite-redis", port: 6379, db: 0)
# rubocop:enable Style/GlobalVars
