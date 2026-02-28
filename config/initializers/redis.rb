# frozen_string_literal: true
# rubocop:disable Style/GlobalVars
$redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0"))
# rubocop:enable Style/GlobalVars
