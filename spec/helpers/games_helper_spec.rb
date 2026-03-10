# frozen_string_literal: true

require "rails_helper"

RSpec.describe GamesHelper do
  describe "#games_sort_options" do
    it "includes the default sort and mobile-friendly labels" do
      expect(helper.games_sort_options).to include(
        ["Last Activity (Newest first)", "last_activity_desc"],
        ["Title (A-Z)", "name_asc"],
        ["Plays (Highest first)", "play_count_desc"]
      )
    end
  end
end
