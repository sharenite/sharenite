module API
  class Base < Grape::API
    before { authenticate_user! }
    mount API::V1::Base
  end
end