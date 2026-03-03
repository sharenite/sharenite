# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Friend do
  it "defines inviter/invitee user associations" do
    expect(described_class.reflect_on_association(:inviter).options[:class_name]).to eq("User")
    expect(described_class.reflect_on_association(:invitee).options[:class_name]).to eq("User")
  end

  it "defines status enum values" do
    expect(described_class.statuses).to include("invited" => "invited", "accepted" => "accepted", "declined" => "declined")
  end
end
