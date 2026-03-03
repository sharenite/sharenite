# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Category do
  it "belongs to user and can be associated with games" do
    association = described_class.reflect_on_association(:user)
    expect(association.macro).to eq(:belongs_to)

    games_association = described_class.reflect_on_association(:games)
    expect(games_association.macro).to eq(:has_and_belongs_to_many)
  end

  it "exposes expected ransack attributes" do
    expect(described_class.ransackable_attributes).to include("name", "playnite_id", "user_id")
  end
end
