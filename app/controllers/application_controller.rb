# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: Rails.application.credentials.http_basic.user,
                              password: Rails.application.credentials.http_basic.password,
                              if: -> { Rails.env.staging? }

  before_action :authenticate_user!
  before_action :set_sentry_context
  
  def set_sentry_context
    return unless current_user
    Sentry.set_user(id: current_user.id)
  end

    def set_sentry_context_admin
    return unless current_admin_user
    Sentry.set_user(id: current_admin_user.id)
  end

  # Devise overrides
  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end
end
