# frozen_string_literal: true

require "rails_helper"

describe Coordinators::FinishPlatformRun do
  describe "call" do
    it "marks the release_platform_run completed" do
      release = create(:release)
      release_platform_run = create(:release_platform_run, release:)
      build = create(:build)
      create(:production_release, release_platform_run:, build:)
      described_class.call(release_platform_run)
      expect(release_platform_run.finished?).to be(true)
      expect(release.reload.partially_finished?).to be(true)
    end

    it "starts post-release on release if only a single platform" do
      release = create(:release)
      release_platform_run = release.release_platform_runs.sole
      release_platform_run.start!
      build = create(:build)
      create(:production_release, release_platform_run:, build:)

      described_class.call(release_platform_run)

      expect(release.reload.post_release_started?).to be(true)
    end

    it "schedules a platform-specific tag job if cross-platform app" do
      app = create(:app, :cross_platform)
      train = create(:train, app:, tag_platform_releases: true)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_platform:)
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      described_class.call(release_platform_run)

      expect(ReleasePlatformRuns::CreateTagJob).to have_received(:perform_later).with(release_platform_run.id).once
    end

    it "does not schedule a platform-specific tag job if cross-platform app tagging all store releases" do
      app = create(:app, :cross_platform)
      train = create(:train, app:, tag_platform_releases: true, tag_all_store_releases: true)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_platform:)
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      described_class.call(release_platform_run)

      expect(ReleasePlatformRuns::CreateTagJob).not_to have_received(:perform_later).with(release_platform_run.id)
    end

    it "does not schedule a platform-specific tag job for single-platform apps" do
      app = create(:app, :android)
      train = create(:train, app:)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_platform:)
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      described_class.call(release_platform_run)

      expect(ReleasePlatformRuns::CreateTagJob).not_to have_received(:perform_later).with(release_platform_run.id)
    end
  end
end
