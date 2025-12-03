# frozen_string_literal: true

require "rails_helper"

describe Coordinators::Signals do
  let(:app) { create(:app, :android) }
  let(:config) {
    {
      workflows: {
        internal: nil,
        release_candidate: {
          name: Faker::FunnyName.name,
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil,
          kind: "release_candidate"
        }
      },
      internal_release: nil,
      beta_release: {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: Faker::FunnyName.name, name: Faker::FunnyName.name, is_internal: true},
            integrable_id: app.id,
            integrable_type: "App"
          }
        ]
      },
      production_release: {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: GooglePlayStoreIntegration::PROD_CHANNEL,
            rollout_config: {enabled: true, stages: [1, 5, 10, 50, 100]},
            integrable_id: app.id,
            integrable_type: "App"
          }
        ]
      }
    }
  }
  let(:release) { create(:release, :on_track) }
  let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }

  describe ".beta_release_is_finished!" do
    let(:beta_release) { create(:beta_release, release_platform_run:) }
    let(:workflow_run) { create(:workflow_run, :rc, release_platform_run:, triggering_release: beta_release) }
    let(:build) { create(:build, release_platform_run:, workflow_run:) }

    it "starts the production release for the release platform run" do
      described_class.beta_release_is_finished!(build)
      expect(release_platform_run.reload.production_releases.size).to eq(1)
      expect(release_platform_run.reload.on_track?).to be(true)
    end

    it "finishes the release platform run if there is no production release configured" do
      release_platform_run.update!(config: config.merge(production_release: nil))
      described_class.beta_release_is_finished!(build)
      expect(release_platform_run.reload.production_releases.size).to eq(0)
      expect(release_platform_run.reload.finished?).to be(true)
    end
  end

  describe ".production_release_is_complete!" do
    let(:production_release) { create(:production_release, :finished, release_platform_run:, build:) }

    it "finishes the release platform run" do
      described_class.production_release_is_complete!(release_platform_run)
      expect(release_platform_run.reload.finished?).to be(true)
    end
  end

  describe ".workflow_run_finished!" do
    let(:workflow_run) { create(:workflow_run, :rc, :finished) }

    before do
      allow(Coordinators::AttachBuildJob).to receive(:perform_async)
    end

    it "triggers the submissions for the triggering release of the workflow run" do
      described_class.workflow_run_finished!(workflow_run.id)
      expect(Coordinators::AttachBuildJob).to have_received(:perform_async).with(workflow_run.id).once
    end
  end

  describe ".build_is_available!" do
    let(:workflow_run) { create(:workflow_run, :rc, :finished) }

    before do
      allow(Coordinators::TriggerSubmissionsJob).to receive(:perform_async)
    end

    it "triggers the submissions for the triggering release of the workflow run" do
      described_class.build_is_available!(workflow_run.id)
      expect(Coordinators::TriggerSubmissionsJob).to have_received(:perform_async).with(workflow_run.id).once
    end
  end

  describe ".beta_release_is_finished! with soak period" do
    let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
    let(:release) { create(:release, :on_track, train:) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }
    let(:beta_release) { create(:beta_release, release_platform_run:) }
    let(:workflow_run) { create(:workflow_run, :rc, release_platform_run:, triggering_release: beta_release) }
    let(:build) { create(:build, release_platform_run:, workflow_run:) }

    it "starts the soak period when beta release finishes" do
      expect {
        described_class.beta_release_is_finished!(build)
      }.to change { release.reload.beta_soak&.started_at }.from(nil)
    end

    it "does not start soak when soak period is disabled" do
      train.update!(soak_period_enabled: false)

      expect {
        described_class.beta_release_is_finished!(build)
      }.not_to change { release.reload.beta_soak&.started_at }
    end

    it "blocks production release when soak period is active" do
      described_class.beta_release_is_finished!(build)
      expect(release_platform_run.reload.production_releases.size).to eq(0)
      expect(release.reload.beta_soak&.started_at).to be_present
      expect(release.reload.beta_soak&.expired?).to be(false)
    end

    it "schedules soak period completion job" do
      allow(Coordinators::SoakPeriodCompletionJob).to receive(:perform_in)
      described_class.beta_release_is_finished!(build)
      expect(Coordinators::SoakPeriodCompletionJob).to have_received(:perform_in).with(24.hours, anything)
    end

    context "when soak period is not enabled" do
      before { train.update!(soak_period_enabled: false) }

      it "proceeds with normal workflow" do
        described_class.beta_release_is_finished!(build)
        expect(release_platform_run.reload.production_releases.size).to eq(1)
        expect(release.reload.beta_soak&.started_at).to be_nil
      end
    end
  end

  describe ".continue_after_soak_period!" do
    let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
    let(:release) { create(:release, :on_track, train:) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }
    let(:beta_release) { create(:beta_release, :finished, release_platform_run:) }
    let(:build) { create(:build, release_platform_run:) }

    before do
      workflow_run = create(:workflow_run, :rc, release_platform_run:, triggering_release: beta_release)
      build.update!(workflow_run: workflow_run)
      create(:beta_soak, :active, release: release)
    end

    it "continues with production release when config is present" do
      expect {
        described_class.continue_after_soak_period!(release)
      }.to change { release_platform_run.reload.production_releases.count }.by(1)
    end

    it "finishes platform run when no production release config" do
      release_platform_run.update!(config: config.merge(production_release: nil))

      described_class.continue_after_soak_period!(release)
      expect(release_platform_run.reload.finished?).to be(true)
    end

    it "skips platform runs without finished beta releases" do
      beta_release.update!(status: "created")

      expect {
        described_class.continue_after_soak_period!(release)
      }.not_to change { release_platform_run.reload.production_releases.count }
    end
  end
end
