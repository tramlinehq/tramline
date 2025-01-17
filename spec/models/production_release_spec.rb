# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductionRelease do
  using RefinedString

  describe "#version_bump_required?" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:current_prod_release_version) { "1.2.0" }
    let(:build) { create(:build, release_platform_run:) }

    it "is false when release platform run has a higher release version" do
      build.update! version_name: current_prod_release_version
      production_release = create(:production_release, :active, build:, release_platform_run:)
      bumped = current_prod_release_version.to_semverish.bump!(:patch).to_s
      release_platform_run.update!(release_version: bumped)
      expect(production_release.version_bump_required?).to be false
    end

    context "when release platform run has the same release version" do
      before do
        release_platform_run.update!(release_version: current_prod_release_version)
      end

      it "is true when production release is active" do
        production_release = create(:production_release, :active, build:, release_platform_run:)
        expect(production_release.version_bump_required?).to be(true)
      end

      it "is false when store submission is in progress" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        create(:play_store_submission, :created, parent_release: production_release)
        expect(production_release.version_bump_required?).to be(false)
      end

      it "is false when store submission is finished and version bump is not required for the store submission" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        create(:play_store_submission, :prepared, parent_release: production_release)
        expect(production_release.version_bump_required?).to be(false)
      end

      it "is true when store submission is finished and version bump is required for the store submission" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        sub = create(:app_store_submission, :approved, parent_release: production_release)
        create(:store_rollout, :app_store, :completed, store_submission: sub, release_platform_run:)
        expect(production_release.version_bump_required?).to be(true)
      end
    end
  end

  describe "#rollout_started!" do
    let(:train) { create(:train, tag_all_store_releases: true, tag_platform_releases: true) }
    let(:release) { create(:release, train:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:, release:) }
    let(:build) { create(:build, release_platform_run:) }
    let(:production_release) { create(:production_release, :inflight, build:, release_platform_run:) }

    before do
      create(:store_rollout,
        :play_store,
        :started,
        store_submission: create(:play_store_submission, :prepared, parent_release: production_release),
        release_platform_run:)
    end

    it "marks the inflight production release as active" do
      production_release.rollout_started!

      expect(production_release.active?).to be(true)
    end

    it "creates a tag for the the production release" do
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      production_release.rollout_started!

      expect(ReleasePlatformRuns::CreateTagJob).to have_received(:perform_later).with(release_platform_run.id, production_release.commit.id)
    end
  end
end
