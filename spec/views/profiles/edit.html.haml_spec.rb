# frozen_string_literal: true
require "rails_helper"

# rubocop:disable RSpec/InstanceVariable
RSpec.describe "profiles/edit" do
  before { @profile = assign(:profile, Profile.create!(name: "MyString", user: nil)) }

  it "renders the edit profile form" do
    render

    assert_select "form[action=?][method=?]", profile_path(@profile), "post" do
      assert_select "input[name=?]", "profile[name]"

      assert_select "input[name=?]", "profile[user_id]"
    end
  end
end
# rubocop:enable all
