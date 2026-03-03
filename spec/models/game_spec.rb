# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game do
  it "belongs to user with counter cache" do
    association = described_class.reflect_on_association(:user)
    expect(association.macro).to eq(:belongs_to)
    expect(association.options[:counter_cache]).to eq(true)
  end

  it "filters by name with filter_by_name scope" do
    user = create(:user)
    matching = described_class.create!(user:, name: "Elden Ring")
    described_class.create!(user:, name: "Portal 2")

    expect(described_class.filter_by_name("Elden")).to contain_exactly(matching)
  end
end
