# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductionRelease do
  describe "#version_bump_required?" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:workflow_run) { create(:workflow_run, :rc, release_platform_run:) }
    let(:build) { create(:build, workflow_run:, release_platform_run:, version_name: "1.2.0") }

    context "when a newer rc build is available" do
      it "is false when the latest rc build does not have the same version as the production release" do
        production_release = create(:production_release, :active, build:, release_platform_run:)
        create(:build, workflow_run:, release_platform_run:, version_name: "1.2.1")
        expect(production_release.version_bump_required?).to be false
      end

      it "is true when the latest rc build does has the same version as the production release" do
        production_release = create(:production_release, :active, build:, release_platform_run:)
        create(:build, workflow_run:, release_platform_run:, version_name: "1.2.0")
        expect(production_release.version_bump_required?).to be true
      end
    end

    context "when no newer rc build is available" do
      it "is true when production release is active" do
        production_release = create(:production_release, :active, build:, release_platform_run:)
        expect(production_release.version_bump_required?).to be(true)
      end

      it "is true when store submission is in progress" do
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
end
