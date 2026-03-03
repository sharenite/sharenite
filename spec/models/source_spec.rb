# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Source do
  it "belongs to user and has dependent games" do
    expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    games_association = described_class.reflect_on_association(:games)
    expect(games_association.macro).to eq(:has_many)
    expect(games_association.options[:dependent]).to eq(:destroy)
  end

  it "exposes expected ransack associations" do
    expect(described_class.ransackable_associations).to include("games", "user")
  end
end
