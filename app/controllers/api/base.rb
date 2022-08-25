# frozen_string_literal: true

module API
  # Base API class
  class Base < Grape::API
    before { authenticate_user! }

    rescue_from :all do |e|
      raise e if Rails.env.development?
      Rollbar.error(e)
      error_response(message: "Internal server error", status: 500)
    end

    mount API::V1::Base
  end
end
