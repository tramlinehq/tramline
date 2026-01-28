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

      expect(release).to have_received(:create_vcs_release!).with(commit.commit_hash, anything, silent: true)
    end

    it "does not block release finalization when tagging fails" do
      train.update(tag_end_of_release: true, backmerge_strategy: "continuous")
      create(:commit, release:)
      allow(release).to receive(:create_vcs_release!) do |*, silent:|
        raise Installations::Error.new("Tag creation failed", reason: :unknown_failure) unless silent
        release.event_stamp!(reason: :tagging_failed, kind: :error, data: {error: "Tag creation failed"})
      end
      allow(release).to receive(:event_stamp!)
      allow(Triggers::PullRequest).to receive(:create_and_merge!).and_return(GitHub::Result.new { true })

      result = described_class.call(release)

      expect(result.ok?).to be(true)
      expect(release).to have_received(:create_vcs_release!).with(anything, anything, silent: true)
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
