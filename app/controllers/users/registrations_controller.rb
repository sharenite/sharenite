# frozen_string_literal: true

module Users
  # Custom Devise registrations flow with conditional reCAPTCHA protection.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_sign_up_params
    before_action :configure_account_update_params
    prepend_before_action :check_captcha

    protected

    def configure_sign_up_params
      return unless action_name == "create"

      devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
    end

    def configure_account_update_params
      return unless action_name == "update"

      devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
    end

    private

    def check_captcha
      return unless action_name == "create"
      return unless captcha_required?
      return if verify_recaptcha # verify_recaptcha(action: 'signup') for v3

      self.resource = resource_class.new sign_up_params
      resource.validate # Look for any other validation errors besides reCAPTCHA
      set_minimum_password_length

      respond_with_navigational(resource) do
        flash.discard(:recaptcha_error) # We need to discard flash to avoid showing it on the next page reload
        render :new
      end
    end
  end
end
