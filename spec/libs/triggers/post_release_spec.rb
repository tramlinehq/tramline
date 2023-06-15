require "rails_helper"

describe Triggers::PostRelease do
  describe ".call" do
    [
      %w[almost_trunk Triggers::PostRelease::AlmostTrunk],
      %w[release_backmerge Triggers::PostRelease::ReleaseBackMerge],
      %w[parallel_working Triggers::PostRelease::ParallelBranches]
    ].each do |branching_strategy, post_release_class|
      context "Given branching strategy – #{branching_strategy}" do
        let(:train) { create(:train, "with_#{branching_strategy}".to_sym) }
        let(:release) { create(:release, :post_release_started, train:) }

        it "dispatches to #{post_release_class} and marks release as finished on success" do
          allow(post_release_class.constantize).to receive(:call).and_return(GitHub::Result.new { true })

          described_class.call(release)

          expect(post_release_class.constantize).to have_received(:call).with(release)
          expect(release.reload.finished?).to be(true)
        end

        it "dispatches to #{post_release_class} and marks release as failed post release on failure" do
          allow(post_release_class.constantize).to receive(:call).and_return(GitHub::Result.new { raise })

          described_class.call(release)

          expect(post_release_class.constantize).to have_received(:call).with(release)
          expect(release.reload.post_release_failed?).to be(true)
        end
      end
    end
  end
end
