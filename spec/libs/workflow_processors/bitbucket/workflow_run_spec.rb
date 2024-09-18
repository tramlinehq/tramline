# frozen_string_literal: true

require "rails_helper"

describe WorkflowProcessors::Bitbucket::WorkflowRun do
  describe "#in_progress?" do
    let(:pipeline_payload) { JSON.parse(File.read("spec/fixtures/bitbucket/pipeline_in_progress.json")).with_indifferent_access }

    it "returns true if the pipeline is in progress" do
      processor = described_class.new(pipeline_payload)
      expect(processor.in_progress?).to be(true)
    end
  end

  describe "#successful?" do
    let(:pipeline_payload) { JSON.parse(File.read("spec/fixtures/bitbucket/pipeline_success.json")).with_indifferent_access }

    it "returns true if the pipeline is in progress" do
      processor = described_class.new(pipeline_payload)
      expect(processor.successful?).to be(true)
    end
  end

  describe "#failed?" do
    let(:pipeline_payload) { JSON.parse(File.read("spec/fixtures/bitbucket/pipeline_fail.json")).with_indifferent_access }

    it "returns true if the pipeline is in progress" do
      processor = described_class.new(pipeline_payload)
      expect(processor.failed?).to be(true)
    end
  end

  describe "#halted?" do
    let(:pipeline_payload) { JSON.parse(File.read("spec/fixtures/bitbucket/pipeline_halted.json")).with_indifferent_access }

    it "returns true if the pipeline is in progress" do
      processor = described_class.new(pipeline_payload)
      expect(processor.halted?).to be(true)
    end
  end

  describe "#started_at" do
    let(:pipeline_payload) { JSON.parse(File.read("spec/fixtures/bitbucket/pipeline_in_progress.json")).with_indifferent_access }

    it "returns the start time of the pipeline" do
      processor = described_class.new(pipeline_payload)
      expect(processor.started_at).to eq("2024-09-04T12:39:39.123027492Z")
    end
  end

  describe "#finished_at" do
    let(:pipeline_payload) { JSON.parse(File.read("spec/fixtures/bitbucket/pipeline_success.json")).with_indifferent_access }

    it "returns the finish time of the pipeline" do
      processor = described_class.new(pipeline_payload)
      expect(processor.finished_at).to eq("2024-09-04T12:47:13.780543208Z")
    end
  end
end
