# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationController do
  describe "#captcha_required?" do
    subject(:captcha_required) { described_class.new.send(:captcha_required?) }

    before do
      described_class.missing_recaptcha_keys_warning_logged = false
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
    end

    context "when captcha is explicitly disabled" do
      before do
        allow(ENV).to receive(:fetch).with("RECAPTCHA_ENABLED", anything).and_return("false")
      end

      it "returns false" do
        expect(captcha_required).to be(false)
      end
    end

    context "when captcha is enabled and keys are present" do
      before do
        allow(ENV).to receive(:fetch).with("RECAPTCHA_ENABLED", anything).and_return("true")
        allow(ENV).to receive(:[]).with("RECAPTCHA_SITE_KEY").and_return("site-key")
        allow(ENV).to receive(:[]).with("RECAPTCHA_SECRET_KEY").and_return("secret-key")
      end

      it "returns true" do
        expect(captcha_required).to be(true)
      end
    end

    context "when captcha is enabled but keys are missing" do
      before do
        allow(ENV).to receive(:fetch).with("RECAPTCHA_ENABLED", anything).and_return("true")
        allow(ENV).to receive(:[]).with("RECAPTCHA_SITE_KEY").and_return(nil)
        allow(ENV).to receive(:[]).with("RECAPTCHA_SECRET_KEY").and_return(nil)
      end

      it "returns false and logs a warning once" do
        expect(Rails.logger).to receive(:warn).with(/RECAPTCHA is enabled but missing site\/secret keys/)
        expect(captcha_required).to be(false)
        expect(captcha_required).to be(false)
      end
    end
  end
end
