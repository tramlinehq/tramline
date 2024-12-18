# frozen_string_literal: true

require "rails_helper"

describe Coordinators::UpdateBuildOnProduction do
  context "when android" do
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
    let(:production_release) { create(:production_release, :inflight, release_platform_run:, build:) }
    let(:store_submission) { create(:play_store_submission, :prepared, release_platform_run:, parent_release: production_release, build:) }

    it "returns an error if the release is not actionable" do
      release_platform_run.update!(status: "stopped")
      expect {
        described_class.call(store_submission, build.id)
      }.to raise_error("production release is not actionable")
    end

    it "returns an error if the production release is not inflight" do
      production_release.update!(status: "active")
      expect {
        described_class.call(store_submission, build.id)
      }.to raise_error("production release is not editable")
    end

    it "returns an error if the build is not found" do
      expect {
        described_class.call(store_submission, "invalid_build_id")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "returns an error if the rc build is not found for the release platform run" do
      new_workflow_run = create(:workflow_run, :internal, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      expect {
        described_class.call(store_submission, new_build.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does nothing id the build is the same as the current build" do
      expect {
        described_class.call(store_submission, build.id)
      }.not_to change(store_submission, :build_id)
    end

    it "attaches the new build to the production store submission" do
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      expect {
        described_class.call(store_submission, new_build.id)
      }.to change(store_submission, :build_id).to(new_build.id)
    end

    it "updates the build number on the production release" do
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      expect {
        described_class.call(store_submission, new_build.id)
      }.to change(production_release, :build_id).to(new_build.id)
    end

    it "does not update the build on the production release if attach build fails" do
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      store_submission.update!(status: "preparing")
      described_class.call(store_submission, new_build.id)
      expect(production_release.reload.build).to eq(build)
    end

    it "retriggers the store submission if the submission was previously triggered" do
      allow(StoreSubmissions::PlayStore::UploadJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      described_class.call(store_submission, new_build.id)
      expect(store_submission.reload.preprocessing?).to be(true)
      expect(StoreSubmissions::PlayStore::UploadJob).to have_received(:perform_async).with(store_submission.id).once
    end

    it "does not retrigger the store submission if attach build fails" do
      allow(StoreSubmissions::PlayStore::UploadJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      store_submission.update!(status: "preparing")
      described_class.call(store_submission, new_build.id)
      expect(StoreSubmissions::PlayStore::UploadJob).not_to have_received(:perform_async).with(store_submission.id)
    end

    it "does not retrigger the store submission if the submission was not previously triggered" do
      store_submission.update!(status: "created")
      allow(StoreSubmissions::PlayStore::UploadJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      described_class.call(store_submission, new_build.id)
      expect(store_submission.reload.created?).to be(true)
      expect(StoreSubmissions::PlayStore::UploadJob).not_to have_received(:perform_async).with(store_submission.id)
    end
  end

  context "when ios" do
    let(:app) { create(:app, :ios) }
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
              submission_type: "TestFlightSubmission",
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
              submission_type: "AppStoreSubmission",
              submission_config: AppStoreIntegration::PROD_CHANNEL,
              rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
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
    let(:production_release) { create(:production_release, :inflight, release_platform_run:, build:) }
    let(:store_submission) { create(:app_store_submission, :prepared, release_platform_run:, parent_release: production_release, build:) }

    it "returns an error if the release is not actionable" do
      release_platform_run.update!(status: "stopped")
      expect {
        described_class.call(store_submission, build.id)
      }.to raise_error("production release is not actionable")
    end

    it "returns an error if the production release is not inflight" do
      production_release.update!(status: "active")
      expect {
        described_class.call(store_submission, build.id)
      }.to raise_error("production release is not editable")
    end

    it "returns an error if the build is not found" do
      expect {
        described_class.call(store_submission, "invalid_build_id")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "returns an error if the rc build is not found for the release platform run" do
      new_workflow_run = create(:workflow_run, :internal, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      expect {
        described_class.call(store_submission, new_build.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does nothing id the build is the same as the current build" do
      expect {
        described_class.call(store_submission, build.id)
      }.not_to change(store_submission, :build_id)
    end

    it "attaches the new build to the production store submission" do
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      expect {
        described_class.call(store_submission, new_build.id)
      }.to change(store_submission, :build_id).to(new_build.id)
    end

    it "does not update the build on the production release if attach build fails" do
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      store_submission.update!(status: "preparing")
      described_class.call(store_submission, new_build.id)
      expect(production_release.reload.build).to eq(build)
    end

    it "updates the build on the production release if attach build succeeds" do
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      expect {
        described_class.call(store_submission, new_build.id)
      }.to change(production_release, :build_id).to(new_build.id)
    end

    it "does not retrigger the store submission if attach build fails" do
      allow(StoreSubmissions::AppStore::FindBuildJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      store_submission.update!(status: "preparing")
      described_class.call(store_submission, new_build.id)
      expect(StoreSubmissions::AppStore::FindBuildJob).not_to have_received(:perform_async).with(store_submission.id)
    end

    it "retriggers the store submission if the submission was previously triggered" do
      allow(StoreSubmissions::AppStore::FindBuildJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      described_class.call(store_submission, new_build.id)
      expect(store_submission.reload.preparing?).to be(true)
      expect(StoreSubmissions::AppStore::FindBuildJob).to have_received(:perform_async).with(store_submission.id).once
    end

    it "retriggers the store submission if the submission was cancelled" do
      store_submission.update!(status: "cancelled")
      allow(StoreSubmissions::AppStore::FindBuildJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      described_class.call(store_submission, new_build.id)
      expect(store_submission.reload.preparing?).to be(true)
      expect(StoreSubmissions::AppStore::FindBuildJob).to have_received(:perform_async).with(store_submission.id).once
    end

    it "does not retrigger the store submission if the submission was not previously triggered" do
      store_submission.update!(status: "created")
      allow(StoreSubmissions::AppStore::FindBuildJob).to receive(:perform_async)
      new_workflow_run = create(:workflow_run, :rc, release_platform_run:)
      new_build = create(:build, release_platform_run:, workflow_run: new_workflow_run)
      described_class.call(store_submission, new_build.id)
      expect(store_submission.reload.created?).to be(true)
      expect(StoreSubmissions::AppStore::FindBuildJob).not_to have_received(:perform_async).with(store_submission.id)
    end
  end
end
