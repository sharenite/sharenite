# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: Rails.application.credentials.http_basic.user, password: Rails.application.credentials.http_basic.password, if: -> { Rails.env.staging? }

  before_action :authenticate_user!
  helper_method :captcha_required?

  # Devise overrides
  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def captcha_required?
    default = Rails.env.production? || Rails.env.staging?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("RECAPTCHA_ENABLED", default))
  end

  def invalid_url!
    raise ActiveRecord::RecordNotFound, "Not Found"
  end
end
