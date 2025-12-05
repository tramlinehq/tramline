# frozen_string_literal: true

require "rails_helper"

describe BuildArtifact do
  describe "#gen_filename" do
    let(:build_artifact) { described_class.allocate }
    let(:app) { create(:app, :android, name: "myapp") }
    let(:build) { create(:build) }

    before do
      allow(build_artifact).to receive_messages(app:, build:)
    end

    it "generates unique filename with UUID" do
      filename1 = build_artifact.gen_filename(".apk")
      filename2 = build_artifact.gen_filename(".apk")

      expect(filename1).to include("myapp")
      expect(filename1).to include(build.version_name)
      expect(filename1).to include("build.apk")
      expect(filename1).not_to eq(filename2) # unique due to UUID
    end

    it "includes all expected components" do
      filename = build_artifact.gen_filename(".ipa")
      expect(filename).to match(/^myapp-.+-[a-f0-9-]{36}-build\.ipa$/)
    end
  end

  describe "#save_file! integration" do
    let(:organization) { create(:organization) }
    let(:app) { create(:app, :android, organization: organization, name: "testapp") }
    let(:release_platform) { create(:release_platform, app: app) }
    let(:release) { create(:release) }
    let(:release_platform_run) { create(:release_platform_run, :android, release_platform: release_platform, release: release) }
    let(:workflow_run) { create(:workflow_run, release_platform_run: release_platform_run) }
    let(:build) { create(:build, workflow_run: workflow_run) }
    let(:build_artifact) { described_class.create!(build: build, generated_at: Time.current) }
    let(:tempfile) { Tempfile.new(%w[test .apk]) }
    let(:artifact_stream) { Artifacts::Stream::StreamIO.new(tempfile, ".apk") }

    before do
      tempfile.write("fake apk content")
      tempfile.rewind
    end

    after do
      tempfile.close
      tempfile.unlink
    end

    context "when organization has no custom storage" do
      it "uploads to default service and sets storage_service" do
        expect(build_artifact.storage_service).to be_nil

        build_artifact.save_file!(artifact_stream)

        expect(build_artifact.file).to be_attached
        expect(build_artifact.file.blob.service_name).to eq(Rails.application.config.active_storage.service.to_s)
        expect(build_artifact.uploaded_at).to be_present
      end
    end

    context "when storage_service is pre-set to different service" do
      before do
        # Simulate artifact created at a different time with different storage
        build_artifact.update!(storage_service: "local")
      end

      it "uses pre-set storage service for point-in-time isolation" do
        expect(build_artifact.storage_service).to eq("local")

        build_artifact.save_file!(artifact_stream)

        expect(build_artifact.file).to be_attached
        expect(build_artifact.file.blob.service_name).to eq("local")
        expect(build_artifact.uploaded_at).to be_present
      end
    end

    it "generates unique file keys for each upload" do
      build_artifact1 = described_class.create!(build: build, generated_at: Time.current)
      build_artifact2 = described_class.create!(build: build, generated_at: Time.current)

      tempfile2 = Tempfile.new(%w[test2 .apk])
      tempfile2.write("fake apk content 2")
      tempfile2.rewind
      artifact_stream2 = Artifacts::Stream::StreamIO.new(tempfile2, ".apk")

      build_artifact1.save_file!(artifact_stream)
      build_artifact2.save_file!(artifact_stream2)

      expect(build_artifact1.file.blob.key).not_to eq(build_artifact2.file.blob.key)

      tempfile2.close
      tempfile2.unlink
    end
  end
end
