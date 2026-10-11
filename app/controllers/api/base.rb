# frozen_string_literal: true

Appsignal.load(:grape)

module API
  # Base API class
  class Base < Grape::API
    use Appsignal::Rack::GrapeMiddleware
    before { authenticate_user! }
    mount API::V1::Base
  end
end
