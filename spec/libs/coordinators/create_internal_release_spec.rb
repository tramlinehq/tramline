# frozen_string_literal: true

require "rails_helper"
using RefinedString

describe Coordinators::CreateInternalRelease do
  before do
    release_platform_run.update!(config:)
  end

  let(:app) { create(:app, :android) }
  let(:config) {
    {
      workflows: {
        internal: {
          name: Faker::FunnyName.name,
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil,
          kind: "internal"
        },
        release_candidate: {
          name: Faker::FunnyName.name,
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil,
          kind: "release_candidate"
        }
      },
      internal_release: {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "GoogleFirebaseSubmission",
            submission_config: {id: Faker::FunnyName.name, name: Faker::FunnyName.name, is_internal: true},
            integrable_id: app.id,
            integrable_type: "App"
          }
        ]
      },
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
  let(:initial_version) { "1.2.0" }
  let(:release) { create(:release, :on_track, is_v2: true, original_release_version: initial_version) }
  let(:release_platform_run) { create(:release_platform_run, :on_track, release:, release_version: initial_version) }
  let(:commit) { create(:commit, release: release_platform_run.release) }

  it "does nothing if release platform run is not on track" do
    release_platform_run.update!(status: "finished")
    described_class.call(release_platform_run, commit)
    expect(release_platform_run.internal_releases.size).to eq(0)
  end

  it "updates the last commit of the release platform run" do
    described_class.call(release_platform_run, commit)
    expect(release_platform_run.last_commit).to eq(commit)
  end

  it "does not bump the version of the release platform run" do
    described_class.call(release_platform_run, commit)
    expect(release_platform_run.reload.release_version).to eq(initial_version)
  end

  it "bumps the version of the release platform run if production release has started" do
    build = create(:build, release_platform_run:, version_name: initial_version)
    _production_release = create(:production_release, :active, release_platform_run:, build:)
    described_class.call(release_platform_run, commit)
    expect(release_platform_run.reload.release_version).to eq(initial_version.to_semverish.bump!(:patch).to_s)
  end

  it "creates an internal release" do
    described_class.call(release_platform_run, commit)
    expect(release_platform_run.internal_releases.size).to eq(1)
  end

  it "triggers the workflow run for the internal release" do
    expect {
      described_class.call(release_platform_run, commit)
    }.to change(WorkflowRuns::TriggerJob.jobs, :size).by(1)

    internal_release = release_platform_run.reload.latest_internal_release
    expect(internal_release.workflow_run).to be_present
    expect(internal_release.workflow_run.triggering?).to be(true)
    expect(WorkflowRuns::TriggerJob.jobs.last["args"]).to eq([internal_release.workflow_run.id])
  end

  it "cancels the previous internal release workflow run if any" do
    previous_internal_release = create(:internal_release, :created, release_platform_run:)
    previous_workflow_run = create(:workflow_run, :started, release_platform_run:, triggering_release: previous_internal_release)

    expect {
      described_class.call(release_platform_run, commit)
    }.to change(WorkflowRuns::CancelJob.jobs, :size).by(1)

    internal_release = release_platform_run.reload.latest_internal_release
    expect(internal_release.previous).to eq(previous_internal_release)
    expect(previous_workflow_run.reload.cancelling?).to be(true)
    expect(WorkflowRuns::CancelJob.jobs.last["args"]).to eq([previous_workflow_run.id])
  end
end
