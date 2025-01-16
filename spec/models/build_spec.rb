require "rails_helper"

describe Build do
  it "has a valid factory" do
    expect(create(:build)).to be_valid
  end

  describe "#release_version" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:commit) { create(:commit) }
    let(:workflow_run) { create(:workflow_run) }

    it "returns versions without suffix if present" do
      allow(workflow_run).to receive(:build_suffix).and_return("staging")

      build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run
      )

      expect(build.release_version).to eq(release_platform_run.release_version)
    end
  end

  describe "#version_name" do
    let(:release_platform_run) { create(:release_platform_run, release_version: "1.3.0") }
    let(:commit) { create(:commit) }
    let(:workflow_run) { create(:workflow_run) }

    it "returns versions with suffix if present" do
      allow(workflow_run).to receive(:build_suffix).and_return("staging")

      build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run
      )

      expect(build.version_name).to eq("1.3.0-staging")
    end
  end

  describe ".create" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:commit) { create(:commit) }
    let(:workflow_run) { create(:workflow_run) }

    it "automatically sets the sequence number based on the release platform run" do
      allow(release_platform_run).to receive(:next_build_sequence_number).and_return(42)

      build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run
      )

      expect(build.sequence_number).to eq(42)
    end

    it "increments sequence number for subsequent builds" do
      first_build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run
      )

      second_build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run
      )

      expect(first_build.sequence_number).to be < second_build.sequence_number
    end
  end
end
