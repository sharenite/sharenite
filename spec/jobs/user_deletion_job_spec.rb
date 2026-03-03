# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDeletionJob, type: :job do
  it "destroys a flagged user" do
    user = create(:user)
    user.update!(deleting: true, deletion_requested_at: Time.current, email: "#{user.id}@sharenite.link")

    expect do
      described_class.perform_now(user.id)
    end.to change(User, :count).by(-1)
  end

  it "does not destroy an unflagged user" do
    user = create(:user)

    expect do
      described_class.perform_now(user.id)
    end.not_to change(User, :count)
  end
end
