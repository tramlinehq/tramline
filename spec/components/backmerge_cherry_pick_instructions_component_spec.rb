require "rails_helper"

describe BackmergeCherryPickInstructionsComponent, type: :component do
  let(:app) { create(:app, :android) }
  let(:working_branch) { "r/dev/2026-01-01" }
  let(:train) { create(:train, working_branch:, app:, branching_strategy: :almost_trunk, backmerge_strategy: :continuous) }
  let(:release) { create(:release, train:) }
  let(:commit) do
    create(:commit, release:, commit_hash: "abc123def456789", message: "Fix bug")
  end

  describe "#commands" do
    it "returns the expected git commands" do
      component = described_class.new(commit)

      expect(component.commands).to eq(
        [
          "git fetch origin",
          "git checkout -b patch-abc123d #{working_branch}",
          "git cherry-pick abc123d",
          "git push -u origin patch-abc123d"
        ]
      )
    end
  end
end
