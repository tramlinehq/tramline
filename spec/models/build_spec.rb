require "rails_helper"

describe Build do
  it "has a valid factory" do
    expect(create(:build)).to be_valid
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
        workflow_run: workflow_run,
        version_name: "1.0.0"
      )

      expect(build.sequence_number).to eq(42)
    end

    it "increments sequence number for subsequent builds" do
      first_build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run,
        version_name: "1.0.0"
      )

      second_build = described_class.create!(
        release_platform_run: release_platform_run,
        commit: commit,
        workflow_run: workflow_run,
        version_name: "1.0.1"
      )

      expect(first_build.sequence_number).to be < second_build.sequence_number
    end
  end
end
