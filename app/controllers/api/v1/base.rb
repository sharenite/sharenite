# frozen_string_literal: true


module API
  module V1
    # Base V1 API module, mounts all endpoints
    class Base < Grape::API
      mount API::V1::Games
      mount API::V1::Users
    end
  end
end
