require "rails_helper"

describe WorkflowProcessors::Teamcity::WorkflowRun do
  let(:integration) { instance_double(TeamcityIntegration) }

  describe "#in_progress?" do
    it "returns true when state is queued" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_queued.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.in_progress?).to be(true)
    end

    it "returns true when state is running" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_running.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.in_progress?).to be(true)
    end

    it "returns false when state is finished" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.in_progress?).to be(false)
    end
  end

  describe "#successful?" do
    it "returns true when finished with SUCCESS status" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.successful?).to be(true)
    end

    it "returns false when finished with FAILURE status" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_failed.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.successful?).to be(false)
    end
  end

  describe "#failed?" do
    it "returns true when finished with FAILURE status" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_failed.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.failed?).to be(true)
    end

    it "returns false when finished with SUCCESS status" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.failed?).to be(false)
    end
  end

  describe "#halted?" do
    it "returns true when cancelled" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_cancelled.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.halted?).to be(true)
    end

    it "returns false when not cancelled" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.halted?).to be(false)
    end
  end

  describe "#error?" do
    it "returns true when finished with ERROR status" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_error.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.error?).to be(true)
    end
  end

  describe "#started_at" do
    it "parses TeamCity date format" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.started_at).to eq(Time.strptime("20240115T143052+0000", "%Y%m%dT%H%M%S%z"))
    end

    it "returns nil when no start date" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_queued.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.started_at).to be_nil
    end
  end

  describe "#finished_at" do
    it "parses TeamCity date format" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.finished_at).to eq(Time.strptime("20240115T144523+0000", "%Y%m%dT%H%M%S%z"))
    end

    it "returns nil when build is still running" do
      payload = JSON.parse(File.read("spec/fixtures/teamcity/build_running.json")).with_indifferent_access
      processor = described_class.new(integration, payload, nil)
      expect(processor.finished_at).to be_nil
    end
  end

  describe "#artifacts_url" do
    it "delegates to integration" do
      payload = {"id" => 123, "state" => "finished", "status" => "SUCCESS"}.with_indifferent_access
      artifact_pattern = "*.apk"
      allow(integration).to receive(:artifact_url).with(123, artifact_pattern).and_return("/path/to/app.apk")

      processor = described_class.new(integration, payload, artifact_pattern)
      expect(processor.artifacts_url).to eq("/path/to/app.apk")
    end
  end
end
