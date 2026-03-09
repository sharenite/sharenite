# frozen_string_literal: true

require Rails.root.join("app/services/request_throttling")

Rails.application.config.middleware.insert_after Warden::Manager, RequestThrottling::Middleware
