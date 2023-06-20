require "rails_helper"

describe Releases::UploadArtifact do
  describe "#perform" do
    let(:artifacts_url) { Faker::Internet.url }
    let(:artifact_fixture) { "spec/fixtures/storage/test_artifact.aab.zip" }
    let(:artifact_file) { Rack::Test::UploadedFile.new(artifact_fixture, "application/zip") }
    let(:artifact_stream) { Artifacts::Stream.new(artifact_file, is_archive: true) }
    let(:step_run) { create(:step_run, :build_ready) }

    it "uploads artifacts and marks run as build available" do
      allow_any_instance_of(GithubIntegration).to receive(:get_artifact).and_return(artifact_stream)
      allow(Triggers::Deployment).to receive(:call)

      described_class.new.perform(step_run.id, artifacts_url)

      expect(step_run.reload.build_available?).to be(true)
      expect(step_run.build_artifact).to be_present
    end

    it "marks run as build_unavailable" do
      allow_any_instance_of(GithubIntegration).to receive(:get_artifact).and_raise(StandardError.new("test error"))

      described_class.new.perform(step_run.id, artifacts_url)

      expect(step_run.reload.build_unavailable?).to be(true)
      expect(step_run.build_artifact).not_to be_present
    end
  end
end
