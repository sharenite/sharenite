# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tag do
  it "belongs to user and has many games through HABTM" do
    expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    expect(described_class.reflect_on_association(:games).macro).to eq(:has_and_belongs_to_many)
  end

  it "exposes expected ransack attributes" do
    expect(described_class.ransackable_attributes).to include("name", "playnite_id", "user_id")
  end
end
