require "rails_helper"

describe Coordinators::FinalizeRelease do
  describe ".call" do
    [
      %w[almost_trunk Coordinators::FinalizeRelease::AlmostTrunk],
      %w[release_backmerge Coordinators::FinalizeRelease::ReleaseBackMerge],
      %w[parallel_working Coordinators::FinalizeRelease::ParallelBranches]
    ].each do |branching_strategy, post_release_class|
      context "with branching strategy – #{branching_strategy}" do
        let(:train) { create(:train, :"with_#{branching_strategy}") }
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

    it "updates the train version" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :post_release_started, train:)

      described_class.call(run)
      train.reload

      expect(train.version_current).to eq("9.60.0")
    end
  end
end
