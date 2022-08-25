# frozen_string_literal: true

module API
  class Base < Grape::API
    before { authenticate_user! }
    mount API::V1::Base
  end
end
