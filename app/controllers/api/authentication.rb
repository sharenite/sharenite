# frozen_string_literal: true

module API
  # Shares Devise's user authentication and cookies with the mounted Grape API.
  module Authentication
    def authenticate_user!
      env["devise.allow_params_authentication"] = true
      error!("401 Forbidden", 401) unless current_user
    end

    def current_user
      @current_user ||= env.fetch("warden").authenticate(scope: :user)
    end
  end
end
