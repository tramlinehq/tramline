require "rails_helper"

describe Releases::UploadArtifact do
  describe "#perform" do
    let(:artifacts_url) { Faker::Internet.url }
    let(:artifact_fixture) { "spec/fixtures/storage/test_artifact.aab.zip" }
    let(:artifact_file) { Rack::Test::UploadedFile.new(artifact_fixture, "application/zip") }
    let(:artifact_stream) { Artifacts::Stream.new(artifact_file, is_archive: true) }
    let(:step_run) { create_deployment_run_tree(:android, step_run_traits: [:build_ready])[:step_run] }

    it "uploads artifacts and marks run as build available" do
      allow_any_instance_of(GithubIntegration).to receive(:get_artifact).and_return(artifact_stream)
      allow(Triggers::Deployment).to receive(:call)

      described_class.new.perform(step_run.id, artifacts_url)

      expect(step_run.reload.build_available?).to be(true)
      expect(step_run.build_artifact).to be_present
    end

    it "retries if artifacts are not found" do
      expect(
        described_class.sidekiq_retry_in_block.call(1, Installations::Errors::ArtifactsNotFound.new)
      ).to be >= 10.seconds
    end

    it "does not retry if there are unexpected errors" do
      expect(
        described_class.sidekiq_retry_in_block.call(1, StandardError.new)
      ).to be(:kill)
    end

    it "does nothing if the run is not active" do
      step_run.release_platform_run.update(status: "finished")

      described_class.new.perform(step_run.id, artifacts_url)

      expect(step_run.reload.build_ready?).to be(true)
    end

    it "does nothing if the step run is cancelled" do
      step_run.update(status: "cancelled")

      described_class.new.perform(step_run.id, artifacts_url)

      expect(step_run.reload.cancelled?).to be(true)
    end
  end
end
