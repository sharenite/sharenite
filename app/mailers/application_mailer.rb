# frozen_string_literal: true

# Base mailer with safe sender fallback when credentials are unavailable.
class ApplicationMailer < ActionMailer::Base
  credentials_default_from = begin
    Rails.application.credentials.dig(:mailer, :default_from)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  default from: ENV["MAILER_DEFAULT_FROM"].presence || credentials_default_from.presence || "no-reply@example.com"
  layout "mailer"
end
