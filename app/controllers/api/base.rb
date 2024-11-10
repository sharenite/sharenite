# frozen_string_literal: true

module API
  # Base API class
  class Base < Grape::API
    insert_before Grape::Middleware::Error, Appsignal::Rack::GrapeMiddleware # Include this middleware
    before { authenticate_user! }
    mount API::V1::Base
  end
end