# frozen_string_literal: true

require "rails_helper"

describe PlayStoreRollout do
  describe "#start_release!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prepared, :prod_release, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }
    let(:rollout) { create(:store_rollout, :play_store, :created, release_platform_run:, store_submission:) }
    let(:prod_double) { instance_double(ProductionRelease) }

    before do
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(prod_double).to receive(:rollout_started!)
      allow(prod_double).to receive(:rollout_complete!)
      allow(rollout).to receive(:parent_release).and_return(prod_double)
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "starts the production release" do
      rollout.start_release!
      expect(rollout.started?).to be(true)
    end

    it "updates the current stage if the rollout is staged" do
      rollout.start_release!
      expect(rollout.current_stage).to eq(0)
    end

    it "informs the production release" do
      rollout.start_release!
      expect(prod_double).to have_received(:rollout_started!)
    end

    context "when the rollout is not staged" do
      let(:rollout) { create(:store_rollout, :play_store, :created, release_platform_run:, store_submission:, is_staged_rollout: false) }

      it "completes the rollout if not staged" do
        rollout.start_release!
        expect(rollout.completed?).to be(true)
        expect(prod_double).to have_received(:rollout_complete!)
      end
    end

    context "when review fails" do
      before do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise play_store_review_error })
      end

      it "marks the submission as failed with action if retry is false" do
        rollout.start_release!
        rollout.store_submission.reload
        expect(rollout.store_submission.failed_with_action_required?).to be(true)
      end

      it "retries (with skip review) if retry is true" do
        rollout.start_release!(retry_on_review_fail: true)
        expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, anything, anything, retry_on_review_fail: true).once
      end
    end
  end

  describe "#move_to_next_stage!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prepared, :prod_release, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "completes the rollout if no more stages left" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.completed?).to be(true)
    end

    it "starts the rollout if it was created" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100])
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.started?).to be(true)
    end

    it "updates the external release if the rollout was started" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100])
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to have_received(:perform_later).with(store_submission.id)
    end

    it "does not update the external release if the rollout was already started" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100])
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).not_to have_received(:perform_later)
    end

    it "promotes the deployment run with the next stage percentage" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(providable_dbl).to(
        have_received(:rollout_release)
          .with(anything, anything, anything, 100, anything, anything)
      )
    end

    it "updates the current stage with the next stage if promote succeeds" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.current_stage).to eq(2)
    end

    it "does not update the current stage with the next stage if promote fails" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.errors?).to be(true)
      expect(rollout.current_stage).to eq(1)
    end

    it "can fail again on retry" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      # first attempt
      rollout.move_to_next_stage!
      expect(rollout.errors?).to be(true)

      # retry attempt
      rollout.move_to_next_stage!
      expect(rollout.errors?).to be(true)
    end

    it "retries (with skip review) when review fails" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!

      expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, anything, anything, retry_on_review_fail: true).once
    end
  end

  describe "#release_fully!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prepared, :prod_release, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "does nothing if the rollout hasn't started" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      rollout = create(:store_rollout, :completed, :play_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "does nothing if the rollout is halted" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "informs the production release about rollout complete" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)

      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout).to receive(:parent_release).and_return(production_release)
      allow(production_release).to receive(:rollout_complete!)

      rollout.release_fully!

      expect(production_release).to have_received(:rollout_complete!)
      expect(rollout.fully_released?).to be(true)
    end

    it "does not inform the production release when rollout cannot complete" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })

      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout).to receive(:parent_release).and_return(production_release)
      allow(production_release).to receive(:rollout_complete!)

      rollout.release_fully!

      expect(production_release).not_to have_received(:rollout_complete!)
      expect(rollout.fully_released?).to be(false)
    end

    it "updates the submission external release" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout).to receive(:parent_release).and_return(production_release)
      allow(production_release).to receive(:rollout_complete!)

      rollout.release_fully!

      expect(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to have_received(:perform_later).with(store_submission.id)
    end

    it "retries (with skip review) when review fails" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.release_fully!

      expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, anything, anything, retry_on_review_fail: true).once
    end
  end

  describe "#halt_release!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prepared, :prod_release, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "halts the rollout if started" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(true)
    end

    it "does nothing if the rollout hasn't started" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      rollout = create(:store_rollout, :completed, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(false)
    end

    it "updates the submission external release" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to have_received(:perform_later).with(store_submission.id)
    end

    it "retries (with skip review) when review fails" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(providable_dbl).to have_received(:halt_release).with(anything, anything, anything, anything, retry_on_review_fail: true).once
    end
  end

  describe "#resume_release!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prepared, :prod_release, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "resumes the rollout if halted" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.resume_release!

      expect(rollout.started?).to be(true)
    end

    it "does not resume the rollout if store call fails" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.resume_release!

      expect(rollout.halted?).to be(true)
      expect(rollout.errors?).to be(true)
    end

    it "updates the submission external release" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.resume_release!

      expect(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to have_received(:perform_later).with(store_submission.id)
    end

    it "retries (with skip review) when review fails" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.resume_release!

      expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, anything, anything, retry_on_review_fail: true).once
    end
  end
end
