# frozen_string_literal: true

require "rails_helper"

describe Coordinators::SoakPeriod::Start do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }

  describe "#call" do
    context "when soak period is enabled" do
      it "starts the soak period when RC is available" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")

        expect {
          described_class.new(release).call
        }.to change { release.reload.soak_started_at }.from(nil)
      end

      it "sets soak_started_at to current time" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")

        freeze_time do
          described_class.new(release).call
          expect(release.reload.soak_started_at).to be_within(1.second).of(Time.current)
        end
      end

      it "does not start soak if already started" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")

        original_time = 1.hour.ago
        release.update!(soak_started_at: original_time)

        expect {
          described_class.new(release).call
        }.not_to change { release.reload.soak_started_at }
      end

      it "does not start soak if no RC is available" do
        expect {
          described_class.new(release).call
        }.not_to change { release.reload.soak_started_at }
      end

      it "stamps an event when soak starts" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")

        expect(release).to receive(:event_stamp!).with(hash_including(reason: :soak_period_started))

        described_class.new(release).call
      end
    end

    context "when soak period is disabled" do
      before do
        train.update!(soak_period_enabled: false)
      end

      it "does not start the soak period" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")

        expect {
          described_class.new(release).call
        }.not_to change { release.reload.soak_started_at }
      end
    end

    context "with multiple platform runs" do
      let(:release_platform_2) { create(:release_platform, train:) }
      let(:release_platform_run_2) { create(:release_platform_run, :on_track, release:, release_platform: release_platform_2) }

      it "starts soak when any platform has RC available" do
        # First platform has no RC
        # Second platform has RC available
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run: release_platform_run_2)
        build = create(:build, release_platform_run: release_platform_run_2, workflow_run:)
        beta_release = create(:beta_release, release_platform_run: release_platform_run_2, build:)
        beta_release.update!(status: "finished")

        expect {
          described_class.new(release).call
        }.to change { release.reload.soak_started_at }.from(nil)
      end
    end

    context "race condition handling" do
      it "prevents duplicate soak starts with locking" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")

        # Simulate concurrent calls
        coordinator1 = described_class.new(release)
        coordinator2 = described_class.new(release)

        # Both coordinators should handle the race gracefully
        coordinator1.call
        coordinator2.call

        # Soak should only be started once
        expect(release.reload.soak_started_at).to be_present
      end
    end
  end
end
