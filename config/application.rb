# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sharenite
  # Application config
  class Application < Rails::Application
    # Keep existing cookie/serialization behavior during the Rails 8 upgrade.
    # Adopt newer framework defaults separately, after reviewing compatibility.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.active_job.queue_adapter = :karafka

    config.autoload_paths += [Rails.root.join("app/api/*").to_s, Rails.root.join("app/services/*").to_s]
  end
end
