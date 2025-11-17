# frozen_string_literal: true

require "rails_helper"

describe Computations::Release::StepStatuses do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }

  describe "#soak_period_status" do
    subject { described_class.new(release).soak_period_status }

    context "when soak period is disabled" do
      before do
        train.update!(soak_period_enabled: false)
      end

      it "returns hidden" do
        expect(subject).to eq(described_class::STATUS[:hidden])
      end
    end

    context "when soak period is enabled" do
      context "when RC is not ready" do
        it "returns blocked" do
          expect(subject).to eq(described_class::STATUS[:blocked])
        end
      end

      context "when RC is ready" do
        before do
          workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
          build = create(:build, release_platform_run:, workflow_run:)
          beta_release = create(:beta_release, release_platform_run:, build:)
          beta_release.update!(status: "finished")
        end

        it "returns blocked when soak has not started" do
          expect(subject).to eq(described_class::STATUS[:blocked])
        end

        it "returns ongoing when soak is active" do
          release.update!(soak_started_at: 1.hour.ago)
          expect(subject).to eq(described_class::STATUS[:ongoing])
        end

        it "returns success when soak has completed" do
          release.update!(soak_started_at: 25.hours.ago)
          expect(subject).to eq(described_class::STATUS[:success])
        end
      end
    end
  end

  describe "#app_submission_status" do
    subject { described_class.new(release).app_submission_status }

    context "when soak period is enabled and active" do
      before do
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "returns blocked" do
        expect(subject).to eq(described_class::STATUS[:blocked])
      end

      it "blocks even if production releases exist" do
        production_release = create(:production_release, release_platform_run:)
        expect(subject).to eq(described_class::STATUS[:blocked])
      end
    end

    context "when soak period is enabled but completed" do
      before do
        release.update!(soak_started_at: 25.hours.ago)
      end

      it "does not block due to soak period" do
        # Will still be blocked due to no production releases, but not due to soak
        expect(subject).to eq(described_class::STATUS[:blocked])
      end

      it "allows submission when production releases exist" do
        production_release = create(:production_release, :finished, release_platform_run:)
        expect(subject).to eq(described_class::STATUS[:success])
      end
    end

    context "when soak period is disabled" do
      before do
        train.update!(soak_period_enabled: false)
      end

      it "does not block due to soak period" do
        # Will be blocked due to no production releases
        expect(subject).to eq(described_class::STATUS[:blocked])
      end
    end
  end

  describe "#call with soak period" do
    subject { described_class.call(release) }

    context "when soak period is enabled" do
      it "includes soak_period status in the response" do
        expect(subject[:statuses]).to have_key(:soak_period)
      end

      it "sets soak_period to blocked when RC not ready" do
        expect(subject[:statuses][:soak_period]).to eq(described_class::STATUS[:blocked])
      end

      it "sets soak_period to ongoing when soak is active" do
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        build = create(:build, release_platform_run:, workflow_run:)
        beta_release = create(:beta_release, release_platform_run:, build:)
        beta_release.update!(status: "finished")
        release.update!(soak_started_at: 1.hour.ago)

        expect(subject[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])
      end
    end

    context "when soak period is disabled" do
      before do
        train.update!(soak_period_enabled: false)
      end

      it "sets soak_period to hidden" do
        expect(subject[:statuses][:soak_period]).to eq(described_class::STATUS[:hidden])
      end
    end
  end

  describe "integration with release states" do
    before do
      workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
      build = create(:build, release_platform_run:, workflow_run:)
      beta_release = create(:beta_release, release_platform_run:, build:)
      beta_release.update!(status: "finished")
    end

    it "transitions from blocked to ongoing when soak starts" do
      statuses_before = described_class.call(release)
      expect(statuses_before[:statuses][:soak_period]).to eq(described_class::STATUS[:blocked])

      release.update!(soak_started_at: 1.hour.ago)

      statuses_after = described_class.call(release)
      expect(statuses_after[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])
    end

    it "transitions from ongoing to success when soak completes" do
      release.update!(soak_started_at: 1.hour.ago)
      statuses_before = described_class.call(release)
      expect(statuses_before[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])

      release.update!(soak_started_at: 25.hours.ago)

      statuses_after = described_class.call(release)
      expect(statuses_after[:statuses][:soak_period]).to eq(described_class::STATUS[:success])
    end
  end
end
