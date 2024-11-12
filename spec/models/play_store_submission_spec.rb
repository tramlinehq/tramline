require "rails_helper"

describe PlayStoreSubmission do
  it "has a valid factory" do
    expect(create(:play_store_submission)).to be_valid
  end

  describe ".start_release!" do
    let(:pre_prod_release) { create(:beta_release) }
    let(:workflow_run) { create(:workflow_run, :rc, :finished, triggering_release: pre_prod_release) }
    let(:build) { create(:build, workflow_run:, release_platform_run: pre_prod_release.release_platform_run) }
    let(:submission) { create(:play_store_submission, :preparing, parent_release: pre_prod_release, build:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow_any_instance_of(PlayStoreRollout).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "creates draft release" do
      allow(providable_dbl).to receive_messages(create_draft_release: GitHub::Result.new, rollout_release: GitHub::Result.new)
      submission.prepare_for_release!
      expect(providable_dbl).to have_received(:create_draft_release)
        .with("production",
          build.build_number,
          build.version_name,
          [{language: "en-US",
            text: "The latest version contains bug fixes and performance improvements."}], anything)
    end

    it "marks the submission as prepared" do
      allow(providable_dbl).to receive_messages(create_draft_release: GitHub::Result.new, rollout_release: GitHub::Result.new)
      expect { submission.prepare_for_release! }.to change(submission, :prepared?)
    end

    context "when review fails" do
      it "retries (with skip review) when its an internal channel" do
        internal_submission = create(:play_store_submission, :preparing, :with_internal_channel, parent_release: pre_prod_release, build:)
        allow(providable_dbl).to receive_messages(create_draft_release: GitHub::Result.new, rollout_release: GitHub::Result.new)

        expect { internal_submission.prepare_for_release! }.to change(internal_submission, :prepared?)
        expect(providable_dbl).to have_received(:create_draft_release).with(anything, anything, anything, anything, retry_on_review_fail: true)
      end

      it "marks the submission as failed with manual action required" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new { raise play_store_review_error })
        expect { submission.prepare_for_release! }.to change(submission, :failed_with_action_required?)
      end

      it "marks the release platform run as blocked for submissions" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new { raise play_store_review_error })
        submission.prepare_for_release!
        expect(submission.release_platform_run.play_store_blocked?).to be true
      end
    end

    it "updates the external release status" do
      allow(providable_dbl).to receive_messages(create_draft_release: GitHub::Result.new, rollout_release: GitHub::Result.new)
      submission.prepare_for_release!
      expect(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to have_received(:perform_later).with(submission.id).at_least(:once)
    end
  end

  describe ".retry" do
    let(:pre_prod_release) { create(:pre_prod_release, :single_submission) }
    let(:workflow_run) { create(:workflow_run, triggering_release: pre_prod_release) }
    let(:build) { create(:build, workflow_run:) }
    let(:submission) { create(:play_store_submission, :failed_with_action_required, parent_release: pre_prod_release, build:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_later)
    end

    it "marks the submission as manually finished if the issue is resolved" do
      allow(providable_dbl).to receive(:build_present_in_channel?).and_return(true)
      expect { submission.retry! }.to change(submission, :finished_manually?).from(false).to(true)
    end

    it "does not do anything if the issue is not resolved" do
      allow(providable_dbl).to receive(:build_present_in_channel?).and_return(false)
      submission.retry!
      expect(submission.finished_manually?).to be(false)
      expect(submission.failed_with_action_required?).to be(true)
    end
  end

  describe "#fully_release_previous_production_rollout!" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:, platform: "android") }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow(providable_dbl).to receive(:find_build_in_track).and_return({status: "inProgress"})
      allow_any_instance_of(PlayStoreRollout).to receive(:provider).and_return(providable_dbl)
    end

    it "skips if the current rollout exists" do
      prev_rollout = create_production_rollout_tree(train, release_platform).dig(:store_rollout)
      create_production_rollout_tree(
        train,
        release_platform,
        release_status: :on_track,
        rollout_status: :created,
        skip_rollout: false
      ) => {store_submission:}

      store_submission.fully_release_previous_production_rollout!

      expect(prev_rollout.reload.status).to eq("completed")
    end

    it "skips if the config is not set to finish previous rollout" do
      prev_rollout = create_production_rollout_tree(train, release_platform).dig(:store_rollout)
      create_production_rollout_tree(
        train,
        release_platform,
        release_status: :on_track,
        rollout_status: :started,
        skip_rollout: true
      ) => {store_submission:}
      store_submission.update!(config: store_submission.config.merge(finish_rollout_in_next_release: false))

      store_submission.fully_release_previous_production_rollout!

      expect(prev_rollout.reload.status).to eq("completed")
    end

    it "skips if the submission is not in a created state" do
      prev_rollout = create_production_rollout_tree(train, release_platform).dig(:store_rollout)
      create_production_rollout_tree(
        train,
        release_platform,
        release_status: :on_track,
        rollout_status: :started,
        submission_status: :preprocessing,
        skip_rollout: true
      ) => {store_submission:}

      store_submission.fully_release_previous_production_rollout!

      expect(prev_rollout.reload.status).to eq("completed")
    end

    it "skips if the previous rollout is not in progress on the store" do
      prev_rollout = create_production_rollout_tree(train, release_platform).dig(:store_rollout)
      create_production_rollout_tree(
        train,
        release_platform,
        release_status: :on_track,
        rollout_status: :started,
        skip_rollout: true
      ) => {store_submission:}
      allow(providable_dbl).to receive(:find_build_in_track).and_return({status: "completed"})

      store_submission.fully_release_previous_production_rollout!

      expect(prev_rollout.reload.status).not_to eq("fully_released")
    end

    it "completes the previous rollout" do
      prev_rollout = create_production_rollout_tree(train, release_platform).dig(:store_rollout)
      create_production_rollout_tree(
        train,
        release_platform,
        release_status: :on_track,
        rollout_status: :started,
        skip_rollout: true
      ) => {store_submission:}
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)

      store_submission.fully_release_previous_production_rollout!

      expect(prev_rollout.reload.status).to eq("fully_released")
    end
  end
end
