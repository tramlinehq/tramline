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
  let(:release) { create(:release, :on_track, is_v2: true) }
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
      allow(V2::TriggerSubmissionsJob).to receive(:perform_later)
    end

    it "triggers the submissions for the triggering release of the workflow run" do
      described_class.workflow_run_finished!(workflow_run.id)
      expect(V2::TriggerSubmissionsJob).to have_received(:perform_later).with(workflow_run.id).once
    end
  end
end
