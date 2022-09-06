# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "profiles/index", type: :view do
  before do
    assign(:profiles, [
      Profile.create!(
        name: "Name",
        user: nil
      ),
      Profile.create!(
        name: "Name",
        user: nil
      )
    ])
  end

  it "renders a list of profiles" do
    render
    assert_select "tr>td", text: "Name".to_s, count: 2
    assert_select "tr>td", text: nil.to_s, count: 2
  end
end
