# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = if Rails.env.development?
    { url: 'redis://sharenite-redis:6379/0' } 
  else
    { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } } # https://stackoverflow.com/questions/65834575/how-to-enable-tls-for-redis-6-on-sidekiq
                 end
end
  
Sidekiq.configure_client do |config|
  config.redis = if Rails.env.development?
    { url: 'redis://sharenite-redis:6379/0' } 
  else
    { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } } # https://stackoverflow.com/questions/65834575/how-to-enable-tls-for-redis-6-on-sidekiq
                 end
end