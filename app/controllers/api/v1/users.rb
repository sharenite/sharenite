# frozen_string_literal: true

module API
  module V1
    # Games API endpoint
    class Users < Grape::API
      include API::V1::Defaults
      resource :users do
        desc "Returns current_user data"
        get "/me" do
          current_user
        end
      end
    end
  end
end
