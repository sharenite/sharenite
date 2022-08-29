# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://sharenite-redis:6379/0' } if Rails.env.development?
end
  
Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://sharenite-redis:6379/0' } if Rails.env.development?
end