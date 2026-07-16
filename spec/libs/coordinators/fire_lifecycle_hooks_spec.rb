require "rails_helper"

describe Coordinators::FireLifecycleHooks do
  let(:train) { create(:train) }
  let(:resource) { instance_double(AppStoreSubmission, train: train, id: "abc-123") }

  before do
    stub_const("FAKE_CLASS_NAME", "AppStoreSubmission")
    allow(resource).to receive(:class).and_return(class_double(AppStoreSubmission, name: "AppStoreSubmission"))
    allow(LifecycleHooks::FireJob).to receive(:perform_async)
  end

  it "enqueues FireJob for each active hook matching the event" do
    matching_active = create(:lifecycle_hook, train: train, event: "ios_submission_started", active: true)
    create(:lifecycle_hook, :inactive, train: train, event: "ios_submission_started")
    create(:lifecycle_hook, train: train, event: "ios_rollout_started", active: true)

    described_class.call(resource, event: :ios_submission_started)

    expect(LifecycleHooks::FireJob).to have_received(:perform_async).with(matching_active.id, "AppStoreSubmission", "abc-123").once
  end

  it "no-ops when no matching active hooks exist" do
    described_class.call(resource, event: :android_rollout_started)
    expect(LifecycleHooks::FireJob).not_to have_received(:perform_async)
  end
end
