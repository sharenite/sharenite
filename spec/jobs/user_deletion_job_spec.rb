# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDeletionJob, type: :job do
  it "destroys a flagged user and marks deletion event as succeeded" do
    user = create(:user)
    user.update!(deleting: true, deletion_requested_at: Time.current, email: "#{user.id}@sharenite.link")
    deletion_event = UserDeletionEvent.create!(requested_at: 2.minutes.ago, status: :requested)

    expect do
      described_class.perform_now(user.id, deletion_event.id)
    end.to change(User, :count).by(-1)

    deletion_event.reload
    expect(deletion_event.status).to eq("succeeded")
    expect(deletion_event.job_started_at).to be_present
    expect(deletion_event.job_succeeded_at).to be_present
  end

  it "does not destroy an unflagged user" do
    user = create(:user)

    expect do
      described_class.perform_now(user.id)
    end.not_to change(User, :count)
  end

  it "marks deletion event as failed when deletion raises" do
    user = create(:user)
    user.update!(deleting: true, deletion_requested_at: Time.current, email: "#{user.id}@sharenite.link")
    deletion_event = UserDeletionEvent.create!(requested_at: 2.minutes.ago, status: :requested)
    failing_user = instance_double(User, deleting?: true)

    allow(failing_user).to receive(:destroy!).and_raise(StandardError, "boom")
    allow(User).to receive(:find_by).with(id: user.id).and_return(failing_user)

    expect do
      described_class.perform_now(user.id, deletion_event.id)
    end.not_to raise_error

    deletion_event.reload
    expect(deletion_event.status).to eq("failed")
    expect(deletion_event.job_started_at).to be_present
    expect(deletion_event.job_failed_at).to be_present
  end
end
