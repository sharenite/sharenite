# frozen_string_literal: true

require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "private override" do
    it "defaults to disabled" do
      expect(build(:playlist).private_override).to be(false)
    end
  end
end
