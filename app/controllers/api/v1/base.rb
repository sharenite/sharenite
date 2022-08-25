# frozen_string_literal: true

# Base V1 API module, mounts all endpoints

module API
  module V1
    class Base < Grape::API
      mount API::V1::Games
    end
  end
end
