require "rails_helper"

shared_examples "end of release tagging" do
  let(:train) { create(:train, :active) }
  let(:release) { create(:release, train: train) }
  let(:release_branch) { release.release_branch }

  context "when tagging is enabled" do
    it "creates a tag" do
      train.update(tag_end_of_release: true)
      commit = create(:commit, release:)
      allow(release).to receive(:create_vcs_release!)

      described_class.call(release)

      expect(release).to have_received(:create_vcs_release!).with(commit.commit_hash, anything)
    end
  end

  context "when tagging is disabled" do
    it "does not create a tag" do
      train.update(tag_end_of_release: false)
      allow(release).to receive(:create_vcs_release!)

      described_class.call(release)

      expect(release).not_to have_received(:create_vcs_release!)
    end
  end
end
