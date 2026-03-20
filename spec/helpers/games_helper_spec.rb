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

  describe "#format_playtime" do
    it "returns the provided zero label when there is no playtime" do
      expect(helper.format_playtime(0, zero_label: "N/A")).to eq("N/A")
    end

    it "formats short playtime in minutes" do
      expect(helper.format_playtime(45.minutes.to_i)).to eq("45 minutes")
    end

    it "keeps long playtime in total hours instead of converting to days" do
      expect(helper.format_playtime(49.hours.to_i + 30.minutes.to_i)).to eq("49 hours 30 minutes")
    end
  end
end
