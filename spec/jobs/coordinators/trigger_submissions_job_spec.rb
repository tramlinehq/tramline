# frozen_string_literal: true

require "rails_helper"

describe Coordinators::TriggerSubmissionsJob do
  let(:ci_cd_double) { instance_double(GithubIntegration) }
  let(:artifacts_url) { Faker::Internet.url }

  before do
    allow_any_instance_of(ReleasePlatformRun).to receive(:ci_cd_provider).and_return(ci_cd_double)
  end

  it "does nothing if release platform run is not on track" do
    release_platform_run = create(:release_platform_run, :finished)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url:)

    described_class.new.perform(workflow_run.id)

    expect(internal_release.store_submissions.size).to eq(0)
  end

  it "attaches the artifact to the build for the workflow run" do
    allow(ci_cd_double).to receive(:get_artifact).and_return({
      stream: Artifacts::Stream.new("spec/fixtures/storage/test_artifact.aab.zip", is_archive: true),
      artifact: {
        generated_at: Time.zone.now,
        size_in_bytes: 10,
        name: "test_artifact_aab.zip",
        id: "123456"
      }
    })
    release_platform_run = create(:release_platform_run, :on_track)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url:)

    described_class.new.perform(workflow_run.id)

    expect(ci_cd_double).to have_received(:get_artifact)
    expect(workflow_run.build.has_artifact?).to be(true)
  end

  it "retries the job if artifact is not found" do
    ex = Installations::Error.new("Artifact not found", reason: :artifact_not_found)
    expect(described_class.new.sidekiq_retry_in_block.call(0, ex)).to eq(30.seconds)
    expect(described_class.new.sidekiq_retry_in_block.call(0, StandardError.new)).to eq(:kill)
  end

  it "raises an error if artifact is not found (to retry) and does not mark the internal release is failed" do
    allow(ci_cd_double).to receive(:get_artifact).and_raise(Installations::Error.new("Artifact not found", reason: :artifact_not_found))
    release_platform_run = create(:release_platform_run, :on_track)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url:)
    workflow_run.build.update!(generated_at: nil)

    expect {
      described_class.new.perform(workflow_run.id)
    }.to raise_error(Installations::Error)

    expect(internal_release.reload.status).to eq("created")
  end

  it "does not raise an error and marks the internal release as failed" do
    allow(ci_cd_double).to receive(:get_artifact).and_raise(StandardError.new)
    release_platform_run = create(:release_platform_run, :on_track)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url:)
    workflow_run.build.update!(generated_at: nil)

    expect {
      described_class.new.perform(workflow_run.id)
    }.not_to raise_error

    expect(internal_release.reload.status).to eq("failed")
  end

  it "triggers the submissions for the pre-prod release" do
    allow(ci_cd_double).to receive(:get_artifact).and_return({
      stream: Artifacts::Stream.new("spec/fixtures/storage/test_artifact.aab.zip", is_archive: true),
      artifact: {
        generated_at: Time.zone.now,
        size_in_bytes: 10,
        name: "test_artifact_aab.zip",
        id: "123456"
      }
    })
    release_platform_run = create(:release_platform_run, :on_track)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url:)

    described_class.new.perform(workflow_run.id)

    expect(internal_release.store_submissions.size).to eq(1)
  end

  it "starts the production release for the hotfix release when release candidate build is finished" do
    allow(ci_cd_double).to receive(:get_artifact).and_return({
      stream: Artifacts::Stream.new("spec/fixtures/storage/test_artifact.aab.zip", is_archive: true),
      artifact: {
        generated_at: Time.zone.now,
        size_in_bytes: 10,
        name: "test_artifact_aab.zip",
        id: "123456"
      }
    })
    release = create(:release, :hotfix, :with_no_platform_runs)
    release_platform_run = create(:release_platform_run, :on_track, release:)
    beta_release = create(:beta_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, :rc, release_platform_run:, triggering_release: beta_release, artifacts_url:)
    create(:build, :with_artifact, release_platform_run:, workflow_run:)

    described_class.new.perform(workflow_run.id)

    expect(release_platform_run.production_releases.size).to eq(1)
  end

  it "does not start the production release for the hotfix release when internal build is finished" do
    allow(ci_cd_double).to receive(:get_artifact).and_return({
      stream: Artifacts::Stream.new("spec/fixtures/storage/test_artifact.aab.zip", is_archive: true),
      artifact: {
        generated_at: Time.zone.now,
        size_in_bytes: 10,
        name: "test_artifact_aab.zip",
        id: "123456"
      }
    })
    release = create(:release, :hotfix, :with_no_platform_runs)
    release_platform_run = create(:release_platform_run, :on_track, release:)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, :internal, release_platform_run:, triggering_release: internal_release, artifacts_url:)
    create(:build, :with_artifact, release_platform_run:, workflow_run:)

    described_class.new.perform(workflow_run.id)

    expect(release_platform_run.production_releases.size).to eq(0)
  end
end
