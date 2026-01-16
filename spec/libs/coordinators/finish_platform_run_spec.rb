# frozen_string_literal: true

require "rails_helper"

describe Coordinators::FinishPlatformRun do
  describe "call" do
    it "marks the release_platform_run concluded" do
      release = create(:release)
      release_platform_run = create(:release_platform_run, release:)
      release_platform_run.start!
      build = create(:build)
      create(:production_release, release_platform_run:, build:)
      described_class.call(release_platform_run)
      expect(release_platform_run.reload.concluded?).to be(true)
      expect(release.reload.partially_finished?).to be(true)
    end

    it "starts post-release on release if only a single platform" do
      release = create(:release, :with_no_platform_runs)
      create(:release_platform_run, release:)
      release_platform_run = release.release_platform_runs.sole
      release_platform_run.start!
      build = create(:build)
      create(:production_release, release_platform_run:, build:)

      described_class.call(release_platform_run)

      expect(release.reload.post_release_started?).to be(true)
    end
  end
end
