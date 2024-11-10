# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

# Add the AppSignal Rack EventHandler
# AppSignal for Ruby gem 3.8+ required
use ::Rack::Events, [Appsignal::Rack::EventHandler.new]

run Rails.application
Rails.application.load_server
