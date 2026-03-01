# frozen_string_literal: true

# Main application controller
class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: Rails.application.credentials.http_basic.user, password: Rails.application.credentials.http_basic.password, if: -> { Rails.env.staging? }

  before_action :redirect_www_to_canonical_host
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

  def redirect_www_to_canonical_host
    return unless Rails.env.production?
    return if request.path == "/up"

    canonical_host = ENV.fetch("HOST").sub(%r{\Ahttps?://}, "").split("/").first
    return unless request.host == "www.#{canonical_host}"

    redirect_to "#{request.protocol}#{canonical_host}#{request.fullpath}", status: :permanent_redirect, allow_other_host: true
  rescue KeyError
    nil
  end
end
