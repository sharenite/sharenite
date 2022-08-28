# frozen_string_literal: true

require "appsignal/integrations/grape"

module API
  # Base API class
  class Base < Grape::API
    before { authenticate_user! }

    rescue_from :all do |e|
      raise e if Rails.env.development?
      Rollbar.error(e)
      error_response(message: "Internal server error", status: 500)
    end
    use Appsignal::Grape::Middleware
    mount API::V1::Base
  end
end
