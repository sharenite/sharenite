# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::ScheduleDeletion do
  include ActiveJob::TestHelper

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "flags user, rewrites email and enqueues async deletion" do
    user = create(:user, email: "delete-me@sharenite.local")

    expect { described_class.call(user) }.to change(UserDeletionEvent, :count).by(1)

    deletion_event = UserDeletionEvent.order(:created_at).last
    deletion_job = enqueued_jobs.find { |job| job[:job] == UserDeletionJob }

    expect(deletion_job).to be_present
    expect(deletion_job[:args]).to eq([user.id, deletion_event.id])

    user.reload
    expect(user.deleting).to be(true)
    expect(user.deletion_requested_at).to be_present
    expect(user.email).to eq("#{user.id}@sharenite.link")
    expect(user.unconfirmed_email).to be_nil
    expect(user.reset_password_token).to be_nil
    expect(user.confirmation_token).to be_nil
    expect(deletion_event.status).to eq("requested")
    expect(deletion_event.requested_at).to be_present
    expect(deletion_event.scheduled_by_admin).to be(false)
    expect(deletion_event.scheduled_by_admin_user_id).to be_nil
    expect(deletion_event.scheduled_by_admin_email).to be_nil
  end

  it "does not enqueue again for an already flagged user" do
    user = create(:user, email: "legacy-flagged@sharenite.local")
    user.update!(deleting: true, deletion_requested_at: Time.current)

    expect do
      described_class.call(user)
    end.not_to change(UserDeletionEvent, :count)

    expect(enqueued_jobs).to be_empty

    user.reload
    expect(user.email).to eq("#{user.id}@sharenite.link")
  end
end
