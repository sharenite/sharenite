# frozen_string_literal: true

require "appsignal/integrations/grape"

module API
  # Base API class
  class Base < Grape::API
    use Appsignal::Grape::Middleware
    before { authenticate_user! }
    mount API::V1::Base
  end
end
