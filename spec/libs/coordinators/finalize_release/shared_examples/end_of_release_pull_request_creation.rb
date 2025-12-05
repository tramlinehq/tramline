require "rails_helper"

shared_examples "end of release pull request creation for almost trunk" do
  let(:train) { create(:train, :active, :with_almost_trunk) }
  let(:release) { create(:release, train: train) }

  before do
    allow(release).to receive(:create_vcs_release!)
    allow(Triggers::PullRequest).to receive(:create_and_merge!).and_return(GitHub::Result.new { true })
  end

  context "when backmerge strategy is on_finalize" do
    before do
      train.update(backmerge_strategy: "on_finalize")
    end

    it "creates and merges a pull request" do
      create(:commit, release: release)

      described_class.call(release)

      expect(Triggers::PullRequest).to have_received(:create_and_merge!).with(
        hash_including(
          release: release,
          new_pull_request_attrs: hash_including(phase: :post_release, kind: :back_merge),
          to_branch_ref: train.working_branch,
          from_branch_ref: release.release_branch
        )
      )
    end
  end

  context "when backmerge strategy is continuous" do
    before do
      train.update(backmerge_strategy: "continuous")
    end

    it "does not create a pull request" do
      described_class.call(release)

      expect(Triggers::PullRequest).not_to have_received(:create_and_merge!)
    end
  end

  context "when backmerge strategy is disabled" do
    before do
      train.update(backmerge_strategy: "disabled")
    end

    it "does not create a pull request" do
      described_class.call(release)

      expect(Triggers::PullRequest).not_to have_received(:create_and_merge!)
    end
  end
end

shared_examples "end of release pull request creation for parallel branches" do
  let(:train) { create(:train, :active, :with_parallel_working) }
  let(:release) { create(:release, train: train) }

  before do
    allow(release).to receive(:create_vcs_release!)
    allow(Triggers::PullRequest).to receive(:create_and_merge!).and_return(GitHub::Result.new { true })
  end

  context "when backmerge strategy is on_finalize" do
    before do
      train.update(backmerge_strategy: "on_finalize")
    end

    it "creates and merges a pull request" do
      create(:commit, release: release)

      described_class.call(release)

      expect(Triggers::PullRequest).to have_received(:create_and_merge!).with(
        hash_including(
          release: release,
          new_pull_request_attrs: hash_including(phase: :post_release, kind: :back_merge),
          to_branch_ref: train.working_branch,
          from_branch_ref: train.release_branch
        )
      )
    end
  end

  context "when backmerge strategy is disabled" do
    before do
      train.update(backmerge_strategy: "disabled")
    end

    it "does not create a pull request" do
      described_class.call(release)

      expect(Triggers::PullRequest).not_to have_received(:create_and_merge!)
    end
  end
end
