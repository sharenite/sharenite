# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "profiles/new" do
  before do
    assign(:profile, Profile.new(
      name: "MyString",
      user: nil
    ))
  end

  it "renders new profile form" do
    render

    assert_select "form[action=?][method=?]", profiles_path, "post" do

      assert_select "input[name=?]", "profile[name]"

      assert_select "input[name=?]", "profile[user_id]"
    end
  end
end
