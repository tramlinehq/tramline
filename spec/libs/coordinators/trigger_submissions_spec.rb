# frozen_string_literal: true

require "rails_helper"

describe Coordinators::TriggerSubmissions do
  it "does nothing if release platform run is not on track" do
    release_platform_run = create(:release_platform_run, :finished)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release)
    described_class.call(workflow_run)
    expect(internal_release.store_submissions.size).to eq(0)
  end

  it "attaches the artifact to the build for the workflow run" do
    ci_cd_double = instance_double(GithubIntegration)
    allow(ci_cd_double).to receive(:get_artifact)

    release_platform_run = create(:release_platform_run, :on_track)
    allow(release_platform_run).to receive(:ci_cd_provider).and_return(ci_cd_double)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url: Faker::Internet.url)
    described_class.call(workflow_run)
    expect(ci_cd_double).to have_received(:get_artifact)
  end

  it "triggers the submissions for the pre prod release" do
    release_platform_run = create(:release_platform_run, :on_track)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release)
    described_class.call(workflow_run)
    expect(internal_release.store_submissions.size).to eq(1)
  end

  it "starts the production release for the hotfix release when release candidate build is finished" do
    release = create(:release, :hotfix, :with_no_platform_runs)
    release_platform_run = create(:release_platform_run, :on_track, release:)
    beta_release = create(:beta_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, :rc, release_platform_run:, triggering_release: beta_release)
    described_class.call(workflow_run)
    expect(release_platform_run.production_releases.size).to eq(1)
  end

  it "does not start the production release for the hotfix release when internal build is finished" do
    release = create(:release, :hotfix, :with_no_platform_runs)
    release_platform_run = create(:release_platform_run, :on_track, release:)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, :internal, release_platform_run:, triggering_release: internal_release)
    described_class.call(workflow_run)
    expect(release_platform_run.production_releases.size).to eq(0)
  end
end
