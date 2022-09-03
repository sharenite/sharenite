# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  http_basic_authenticate_with name:
                                 Rails.application.credentials.http_basic.user,
                               password:
                                 Rails
                                   .application
                                   .credentials
                                   .http_basic
                                   .password,
                               if: -> { Rails.env.staging? }

  before_action :authenticate_user!

  # Devise overrides
  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def invalid_url!
    raise ActionController::RoutingError, "Not Found"
  end
end
