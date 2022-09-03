# frozen_string_literal: true

require "appsignal/integrations/grape"

module API
  # Base API class
  class Base < Grape::API
    before { authenticate_user! }

    use Appsignal::Grape::Middleware
    mount API::V1::Base
  end
end
