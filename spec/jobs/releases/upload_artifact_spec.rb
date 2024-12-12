require "rails_helper"

RSpec.describe Releases::UploadArtifact do
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

    describe "retry behavior" do
      it "retries with correct backoff when artifact is not found" do
        error = Installations::Error.new("Could not find the artifact", reason: :artifact_not_found)
        allow_any_instance_of(GithubIntegration).to receive(:get_artifact).and_raise(error)
        allow(described_class).to receive(:perform_in)

        job = described_class.new
        expect {
          job.perform(step_run.id, artifacts_url)
        }.to raise_error(Installations::Error)

        expect(described_class).to have_received(:perform_in).with(
          15, # Actual backoff time
          step_run.id,
          hash_including(
            "retry_count" => 1,
            "step_run_id" => step_run.id,
            "original_exception" => hash_including(
              "class" => "Installations::Error",
              "message" => "Could not find the artifact"
            )
          )
        )
      end

      it "handles retries exhausted" do
        error = Installations::Error.new("Could not find the artifact", reason: :artifact_not_found)
        job = described_class.new

        allow(StepRun).to receive(:find).and_return(step_run)
        allow(step_run).to receive(:build_upload_failed!)
        allow(step_run).to receive(:event_stamp!)

        job.handle_retries_exhausted(
          step_run_id: step_run.id,
          last_exception: error
        )

        expect(step_run).to have_received(:build_upload_failed!)
        expect(step_run).to have_received(:event_stamp!).with(
          reason: :build_unavailable,
          kind: :error,
          data: {version: step_run.build_version}
        )
      end
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
