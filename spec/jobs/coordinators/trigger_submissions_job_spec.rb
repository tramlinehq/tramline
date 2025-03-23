# frozen_string_literal: true

require "rails_helper"

describe Coordinators::TriggerSubmissionsJob do
  let(:artifacts_url) { Faker::Internet.url }

  it "triggers the submissions for the pre-prod release" do
    release_platform_run = create(:release_platform_run, :on_track)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: internal_release, artifacts_url:)

    described_class.new.perform(workflow_run.id)

    expect(internal_release.store_submissions.size).to eq(1)
  end

  it "starts the production release for the hotfix release when release candidate build is finished" do
    release = create(:release, :hotfix, :with_no_platform_runs)
    release_platform_run = create(:release_platform_run, :on_track, release:)
    beta_release = create(:beta_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, :rc, release_platform_run:, triggering_release: beta_release, artifacts_url:)
    create(:build, :with_artifact, release_platform_run:, workflow_run:)

    described_class.new.perform(workflow_run.id)

    expect(release_platform_run.production_releases.size).to eq(1)
  end

  it "does not start the production release for the hotfix release when internal build is finished" do
    release = create(:release, :hotfix, :with_no_platform_runs)
    release_platform_run = create(:release_platform_run, :on_track, release:)
    internal_release = create(:internal_release, release_platform_run:)
    workflow_run = create(:workflow_run, :finished, :internal, release_platform_run:, triggering_release: internal_release, artifacts_url:)
    create(:build, :with_artifact, release_platform_run:, workflow_run:)

    described_class.new.perform(workflow_run.id)

    expect(release_platform_run.production_releases.size).to eq(0)
  end
end
