# frozen_string_literal: true

require "rails_helper"

describe ScheduledReleaseNotificationJob do
  let(:train) { create(:train, :active) }
  let(:release) { create(:release, train:) }

  it "sends a notification" do
    scheduled_release = create(:scheduled_release, train:, release:)
    allow(ScheduledRelease).to receive(:find_by).with(id: scheduled_release.id).and_return(scheduled_release)
    allow(scheduled_release.train).to receive(:notify!)

    described_class.new.perform(scheduled_release.id)

    expect(scheduled_release.train).to have_received(:notify!).with(
      "A release is scheduled",
      :release_scheduled,
      scheduled_release.notification_params
    )
  end

  it "does not send a notification when scheduled release was manually skipped" do
    scheduled_release = create(:scheduled_release, train:, release:, manually_skipped: true)
    allow(ScheduledRelease).to receive(:find_by).with(id: scheduled_release.id).and_return(scheduled_release)
    allow(scheduled_release.train).to receive(:notify!)

    described_class.new.perform(scheduled_release.id)

    expect(scheduled_release.train).not_to have_received(:notify!)
  end

  it "does not send a notification when train is inactive" do
    inactive_train = create(:train, :inactive)
    scheduled_release = create(:scheduled_release, train: inactive_train, release:)
    allow(ScheduledRelease).to receive(:find_by).with(id: scheduled_release.id).and_return(scheduled_release)
    allow(inactive_train).to receive(:notify!)

    described_class.new.perform(scheduled_release.id)

    expect(inactive_train).not_to have_received(:notify!)
  end
end
