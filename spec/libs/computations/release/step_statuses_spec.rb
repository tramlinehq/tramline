# frozen_string_literal: true

require "rails_helper"

describe Computations::Release::StepStatuses do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, :with_no_platform_runs, train:) }
  let(:release_platform_run) { create(:release_platform_run, release: release) }

  describe "#soak_period_status" do
    subject(:soak_status) { described_class.new(release).soak_period_status }

    it "returns hidden when soak period is disabled" do
      train.update!(soak_period_enabled: false)
      expect(soak_status).to eq(described_class::STATUS[:hidden])
    end

    context "when soak period is enabled" do
      context "when RC is not ready" do
        it "returns blocked" do
          expect(soak_status).to eq(described_class::STATUS[:blocked])
        end
      end

      context "when RC is ready" do
        before do
          commit = create(:commit, release: release)
          release_platform_run.update!(last_commit: commit)
          workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
          create(:build, release_platform_run:, workflow_run:)
          create(:beta_release, :finished, release_platform_run:, triggered_workflow_run: workflow_run, commit: commit)
        end

        it "returns ongoing when no soak exists yet" do
          expect(soak_status).to eq(described_class::STATUS[:ongoing])
        end

        it "returns ongoing when soak is active" do
          create(:beta_soak, :active, release: release)
          expect(soak_status).to eq(described_class::STATUS[:ongoing])
        end

        it "returns success when soak has ended manually" do
          create(:beta_soak, :ended, release: release)
          expect(soak_status).to eq(described_class::STATUS[:success])
        end
      end
    end
  end

  describe "#app_submission_status" do
    subject(:submission_status) { described_class.new(release).app_submission_status }

    context "when soak period is enabled and active" do
      before do
        create(:beta_soak, :active, release: release)
      end

      it "returns blocked" do
        expect(submission_status).to eq(described_class::STATUS[:blocked])
      end
    end

    context "when soak period is enabled but ended" do
      before do
        create(:beta_soak, :ended, release: release)
      end

      it "does not block due to soak period" do
        # Will still be blocked due to no production releases, but not due to soak
        expect(submission_status).to eq(described_class::STATUS[:blocked])
      end
    end

    context "when soak period is disabled" do
      before do
        train.update!(soak_period_enabled: false)
      end

      it "does not block due to soak period" do
        # Will be blocked due to no production releases
        expect(submission_status).to eq(described_class::STATUS[:blocked])
      end
    end
  end

  describe "#call" do
    before do
      create(:release_platform_run, release: release)
      release.reload
    end

    context "when soak period is enabled" do
      it "includes soak_period status in the response" do
        res = described_class.call(release)
        expect(res[:statuses]).to have_key(:soak_period)
      end

      it "sets soak_period to blocked when RC not ready" do
        res = described_class.call(release)
        expect(res[:statuses][:soak_period]).to eq(described_class::STATUS[:blocked])
      end

      it "sets soak_period to ongoing when soak is active" do
        commit = create(:commit, release: release)
        release_platform_run.update!(last_commit: commit)
        workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
        create(:build, release_platform_run:, workflow_run:)
        create(:beta_release, :finished, release_platform_run:, triggered_workflow_run: workflow_run, commit: commit)
        create(:beta_soak, :active, release: release)

        res = described_class.call(release)
        expect(res[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])
      end
    end

    context "when soak period is disabled" do
      it "sets soak_period to hidden" do
        train.update!(soak_period_enabled: false)
        res = described_class.call(release)
        expect(res[:statuses][:soak_period]).to eq(described_class::STATUS[:hidden])
      end
    end
  end

  describe "integration with release states" do
    before do
      release_platform_run = create(:release_platform_run, release: release)
      release.reload
      commit = create(:commit, release: release)
      release_platform_run.update!(last_commit: commit)
      workflow_run = create(:workflow_run, :rc, :finished, release_platform_run:)
      create(:build, release_platform_run:, workflow_run:)
      create(:beta_release, :finished, release_platform_run:, triggered_workflow_run: workflow_run, commit: commit)
    end

    it "remains ongoing both before and after soak starts" do
      # When RC is ready but no soak exists yet
      statuses_before = described_class.call(release)
      expect(statuses_before[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])

      # When soak is created and active
      create(:beta_soak, :active, release: release)
      statuses_after = described_class.call(release)
      expect(statuses_after[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])
    end

    it "transitions from ongoing to success when soak is ended manually" do
      beta_soak = create(:beta_soak, :active, release: release)
      statuses_before = described_class.call(release)
      expect(statuses_before[:statuses][:soak_period]).to eq(described_class::STATUS[:ongoing])

      beta_soak.update!(ended_at: Time.current)

      statuses_after = described_class.call(release)
      expect(statuses_after[:statuses][:soak_period]).to eq(described_class::STATUS[:success])
    end
  end
end
