# frozen_string_literal: true

require "rails_helper"

describe PreProdRelease do
  describe "#trigger_submissions!" do
    let(:pre_prod_release) { create(:internal_release) }
    let(:workflow_run) { create(:workflow_run, triggering_release: pre_prod_release) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(PlayStoreSubmission).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:find_build).and_return(true)
    end

    it "triggers the first submission" do
      build = create(:build, workflow_run:)
      pre_prod_release.trigger_submissions!(build)
      expect(pre_prod_release.store_submissions.count).to eq(1)
      expect(pre_prod_release.store_submissions.sole.build).to eq(build)
      expect(pre_prod_release.store_submissions.sole.preparing?).to be true
    end
  end

  describe "#rollout_complete!" do
    let(:pre_prod_release) { create(:internal_release) }
    let(:workflow_run) { create(:workflow_run, triggering_release: pre_prod_release) }
    let(:build) { create(:build, workflow_run:) }
    let(:submission) { create(:play_store_submission, parent_release: pre_prod_release, build:, sequence_number: 1) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(PlayStoreSubmission).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:find_build).and_return(true)
    end

    it "triggers the next submission" do
      pre_prod_release.rollout_complete!(submission)
      expect(pre_prod_release.store_submissions.count).to eq(2)
      expect(pre_prod_release.store_submissions.find_by(sequence_number: 2).preparing?).to be true
    end

    it "finishes the release if there are no more submissions" do
      next_submission = create(:play_store_submission, parent_release: pre_prod_release, build:, sequence_number: 2)
      pre_prod_release.rollout_complete!(next_submission)
      expect(pre_prod_release.finished?).to be true
    end

    context "when auto promote is disabled" do
      let(:config) {
        {auto_promote: true,
         submissions: [
           {number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: :internal, name: "internal testing"},
            rollout_config: [100],
            auto_promote: true},
           {number: 2,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: :alpha, name: "closed testing"},
            rollout_config: [10, 100],
            auto_promote: false}
         ]}
      }
      let(:pre_prod_release) { create(:pre_prod_release, config:) }

      it "does not trigger the next submission if auto_promote is false" do
        pre_prod_release.rollout_complete!(submission)
        expect(pre_prod_release.store_submissions.count).to eq(2)
        expect(pre_prod_release.store_submissions.find_by(sequence_number: 2).created?).to be true
      end
    end
  end
end
