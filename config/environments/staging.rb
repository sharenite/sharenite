# frozen_string_literal: true

# Just use the production settings
require File.expand_path("production.rb", __dir__)

Rails.application.configure do
  # Trust SSL termination at kamal-proxy and avoid redirecting the health check.
  config.assume_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
  config.silence_healthcheck_path = "/up"
end
