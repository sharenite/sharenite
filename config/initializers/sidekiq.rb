# frozen_string_literal: true

require "sidekiq"
require "sidekiq-unique-jobs"

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://sharenite-redis:6379/0" }

  config.client_middleware { |chain| chain.add SidekiqUniqueJobs::Middleware::Client }

  config.server_middleware { |chain| chain.add SidekiqUniqueJobs::Middleware::Server }

  SidekiqUniqueJobs::Server.configure(config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://sharenite-redis:6379/0" }

  config.client_middleware { |chain| chain.add SidekiqUniqueJobs::Middleware::Client }
end
