# frozen_string_literal: true

require "rails_helper"

describe Coordinators::FinalizePlatformRun do
  describe "call" do
    it "marks the release_platform_run finished" do
      release = create(:release)
      release_platform_run = create(:release_platform_run, release:)
      release_platform_run.start!
      release_platform_run.conclude!

      described_class.call(release_platform_run)

      expect(release_platform_run.reload.finished?).to be(true)
      expect(release_platform_run.completed_at).to be_present
    end

    it "sets completed_at timestamp" do
      release = create(:release)
      release_platform_run = create(:release_platform_run, release:)
      release_platform_run.start!
      release_platform_run.conclude!

      expect(release_platform_run.completed_at).to be_nil

      described_class.call(release_platform_run)

      expect(release_platform_run.reload.completed_at).to be_within(1.second).of(Time.current)
    end

    it "stamps the finalized event" do
      release = create(:release)
      release_platform_run = create(:release_platform_run, release:)
      release_platform_run.start!
      release_platform_run.conclude!

      expect {
        described_class.call(release_platform_run)
      }.to change { release_platform_run.passports.count }.by(1)

      event = release_platform_run.passports.last
      expect(event.reason).to eq("finished")
    end
  end
end
