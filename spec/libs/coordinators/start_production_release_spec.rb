# frozen_string_literal: true

require "rails_helper"

describe Coordinators::StartProductionRelease do
  describe "call" do
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
    let(:workflow_run) { create(:workflow_run, :rc, release_platform_run:) }
    let(:build) { create(:build, release_platform_run:, workflow_run:) }

    it "does nothing if release platform run is not on track" do
      release_platform_run.update!(status: "finished")
      expect {
        described_class.call(release_platform_run, build.id)
      }.not_to change(release_platform_run.production_releases, :size)
    end

    it "does nothing if there the previous production release is inflight" do
      _previous_production_release = create(:production_release, :inflight, release_platform_run:)
      expect {
        described_class.call(release_platform_run, build.id)
      }.not_to change(release_platform_run.reload.production_releases, :size)
    end

    it "creates a production release" do
      described_class.call(release_platform_run, build.id)
      expect(release_platform_run.reload.production_releases.size).to eq(1)
    end

    it "starts a submission" do
      expect {
        described_class.call(release_platform_run, build.id)
      }.to change(release_platform_run.reload.store_submissions, :count).by(1)
    end

    it "assigns the previous production release to the new one" do
      previous_production_release = create(:production_release, :active, release_platform_run:)
      described_class.call(release_platform_run, build.id)
      production_release = release_platform_run.reload.latest_production_release
      expect(production_release.previous).to eq(previous_production_release)
    end
  end
end
