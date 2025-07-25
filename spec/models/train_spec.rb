require "rails_helper"

describe Train do
  describe "#disable_copy_approvals" do
    let(:copy_approval_train) { create(:train, copy_approvals: true) }

    context "when approvals are not enabled" do
      let(:copy_approval_train) { create(:train, copy_approvals: true, approvals_enabled: false) }

      it "sets copy_approvals to false before update" do
        copy_approval_train.update!(name: "Updated Train Name") # Trigger the update
        expect(copy_approval_train.reload.copy_approvals).to be(false)
      end

      it "ensures both approvals_enabled and copy_approvals are false when explicitly set" do
        copy_approval_train.update!(copy_approvals: true, approvals_enabled: false)
        expect(copy_approval_train.reload.copy_approvals).to be(false)
        expect(copy_approval_train.approvals_enabled?).to be(false)
      end

      it "keeps both approvals_enabled and copy_approvals as false when explicitly set" do
        copy_approval_train.update!(copy_approvals: false, approvals_enabled: false)
        expect(copy_approval_train.approvals_enabled?).to be(false)
      end
    end

    context "when approvals are enabled" do
      before do
        allow(copy_approval_train).to receive(:approvals_enabled?).and_return(true)
      end

      it "does not change copy_approvals when no custom value is provided" do
        copy_approval_train.update!(name: "Updated Train Name")
        expect(copy_approval_train.reload.copy_approvals).to be(true)
      end

      it "allows setting a custom value for copy_approvals when approvals are enabled" do
        copy_approval_train.update!(copy_approvals: false)
        expect(copy_approval_train.reload.copy_approvals).to be(false)
      end
    end
  end

  it "has a valid factory" do
    expect(create(:train)).to be_valid
  end

  describe "#set_current_version" do
    it "sets it to the version_seeded_with" do
      ver = "1.2.3"
      train = build(:train, version_seeded_with: ver)

      expect(train.version_current).to be_nil
      train.save!
      expect(train.version_current).to eq(ver)
    end
  end

  describe "#create_release_platforms" do
    it "creates a release platform with android for android app" do
      app = create(:app, :android)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(1)
      expect(train.reload.release_platforms.first.platform).to eq(app.platform)
    end

    it "creates a release platform with ios for ios app" do
      app = create(:app, :ios)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(1)
      expect(train.reload.release_platforms.first.platform).to eq(app.platform)
    end

    it "creates a release platform per platform for cross-platform app" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(2)
      expect(train.reload.release_platforms.pluck(:platform)).to match_array(ReleasePlatform.platforms.keys)
    end
  end

  describe "#activate!" do
    it "marks the train as active" do
      train = create(:train, :draft)
      train.activate!

      expect(train.reload.active?).to be(true)
    end

    it "marks an inactive train as active" do
      train = create(:train, :inactive)
      train.activate!

      expect(train.reload.active?).to be(true)
    end

    it "schedules the release for an automatic train" do
      train = create(:train, :with_schedule, :draft)
      train.activate!

      expect(train.reload.scheduled_releases.count).to be(1)
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(train.kickoff_at)
    end
  end

  describe "#next_run_at" do
    it "returns kickoff time if no releases have been scheduled yet and kickoff is in the future" do
      train = create(:train, :with_schedule, :active)

      expect(train.next_run_at).to eq(train.kickoff_at)
    end

    it "returns kickoff + repeat duration time if no releases have been scheduled yet and kickoff is in the past" do
      train = create(:train, :with_schedule, :active)

      travel_to train.kickoff_at + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration)
      end
    end

    it "returns next available schedule time if there is a scheduled release" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

      travel_to train.kickoff_at + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration)
      end
    end

    it "returns next available schedule time if there are many scheduled releases" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at + train.repeat_duration)

      travel_to train.kickoff_at + 1.day + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration * 2)
      end
    end

    it "returns next available schedule time if there are scheduled releases and more than repeat duration has passed since last scheduled release" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

      travel_to train.kickoff_at + 2.days + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration * 3)
      end
    end
  end

  describe "#deactivate" do
    it "deletes the pending scheduled releases for an automatic train" do
      train = create(:train, :with_schedule, :draft)
      train.activate!
      expect(train.scheduled_releases.count).to be(1)

      train.deactivate!

      expect(train.reload.scheduled_releases.count).to be(0)
    end

    it "marks the train as inactive" do
      train = create(:train, :active)

      train.deactivate!

      expect(train.reload.inactive?).to be(true)
    end
  end

  describe "#update" do
    it "schedules the release for an automatic train" do
      train = create(:train, :with_almost_trunk, :active)
      expect(train.scheduled_releases.count).to be(0)

      train.update!(kickoff_at: 2.days.from_now, repeat_duration: 2.days)

      expect(train.reload.scheduled_releases.count).to be(1)
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(train.kickoff_at)
    end
  end

  describe "#hotfix_from" do
    let(:train) { create(:train, :with_almost_trunk, :active) }
    let(:release) { create(:release, :with_no_platform_runs, train:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_platform_run) { create(:release_platform_run, release:, release_platform:) }

    it "returns the last finished release" do
      create(:release, :finished, :with_no_platform_runs, train:, completed_at: 2.hours.ago)
      latest_release = create(:release, :finished, :with_no_platform_runs, train:, completed_at: Time.current)

      expect(train.hotfix_from).to eq(latest_release)
    end

    it "returns nothing if no finished releases" do
      expect(train.hotfix_from).to be_nil
    end
  end

  describe "#release_branch_name_fmt" do
    it "adds hotfix to branch name if hotfix" do
      train = create(:train, :with_almost_trunk, :active)
      tokens = {trainName: "train", releaseStartDate: "%Y-%m-%d"}

      expect(train.release_branch_name_fmt(hotfix: true, substitution_tokens: tokens)).to eq("hotfix/train/%Y-%m-%d")
    end

    it "uses default pattern when no custom pattern is set" do
      train = create(:train, :with_almost_trunk, :active)
      tokens = {trainName: "train", releaseStartDate: "%Y-%m-%d"}

      expect(train.release_branch_name_fmt(substitution_tokens: tokens)).to eq("r/train/%Y-%m-%d")
    end

    it "uses custom pattern when release_branch_pattern is set" do
      train = create(:train, :with_almost_trunk, :active, release_branch_pattern: "release/~trainName~/%Y-%m-%d-%H%M")
      tokens = {trainName: "train"}

      expect(train.release_branch_name_fmt(substitution_tokens: tokens)).to eq("release/train/%Y-%m-%d-%H%M")
    end

    it "substitutes trainName placeholder in custom pattern" do
      train = create(:train, :with_almost_trunk, :active, name: "My Custom Train", release_branch_pattern: "custom/~trainName~/v%Y.%m")
      tokens = {trainName: "My Custom Train"}

      expect(train.release_branch_name_fmt(substitution_tokens: tokens)).to eq("custom/my-custom-train/v%Y.%m")
    end

    it "substitutes releaseVersion placeholder in custom pattern" do
      train = create(:train, :with_almost_trunk, :active, release_branch_pattern: "r/~trainName~/~releaseVersion~")
      tokens = {trainName: "train", releaseVersion: "1.2.3"}

      expect(train.release_branch_name_fmt(substitution_tokens: tokens)).to eq("r/train/1.2.3")
    end

    it "substitutes multiple placeholders in custom pattern" do
      train = create(:train, :with_almost_trunk, :active, name: "My Train", release_branch_pattern: "release/~trainName~/~releaseVersion~/~releaseStartDate~")
      tokens = {trainName: "My Train", releaseVersion: "1.2.3", releaseStartDate: "2023-12-25"}

      expect(train.release_branch_name_fmt(substitution_tokens: tokens)).to eq("release/my-train/1.2.3/2023-12-25")
    end
  end

  describe "#hotfixable?" do
    let(:train) { create(:train, :with_no_platforms) }

    before do
      create(:release_platform, train:)
    end

    it "is false when the train has no production releases" do
      release_platform = train.release_platforms.sole
      new_beta_step = Config::ReleaseStep.from_json(
        {
          kind: "beta",
          auto_promote: false,
          submissions: [
            {number: 1,
             submission_type: "AppStoreSubmission",
             submission_config: {id: "123", name: "Internal"},
             rollout_config: {enabled: false},
             integrable_id: train.app.id,
             integrable_type: "App",
             auto_promote: false}
          ]
        }.with_indifferent_access
      )
      release_platform.platform_config.update!(production_release: nil, beta_release: new_beta_step)
      expect(train.reload.hotfixable?).to be(false)
    end

    it "is false when there is no completed release to hotfix" do
      expect(train.reload.hotfixable?).to be(false)
    end

    it "is true when there is a completed release to hotfix and no ongoing release" do
      create(:release, :finished, train:)
      expect(train.reload.hotfixable?).to be(true)
    end

    it "is false when there is already an ongoing hotfix release" do
      create(:release, :hotfix, :on_track, train:)
      expect(train.reload.hotfixable?).to be(false)
    end

    it "is false when the ongoing release is being actively rolled out" do
      _completed_release = create(:release, :finished, train:)
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:)
      release_platform_run = create(:release_platform_run, release: ongoing_release, release_platform: train.release_platforms.sole)
      production_release = create(:production_release, :active, release_platform_run:, build: create(:build))
      create(:play_store_submission, :prepared, parent_release: production_release)
      create(:store_rollout, :started, release_platform_run:, store_submission: production_release.store_submission)
      expect(train.reload.hotfixable?).to be(false)
    end

    it "is true when the ongoing release is ready to rollout" do
      _completed_release = create(:release, :finished, train:)
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:)
      release_platform_run = create(:release_platform_run, release: ongoing_release, release_platform: train.release_platforms.sole)
      production_release = create(:production_release, :active, release_platform_run:, build: create(:build))
      create(:play_store_submission, :prepared, parent_release: production_release)
      create(:store_rollout, :created, release_platform_run:, store_submission: production_release.store_submission)
      expect(train.reload.hotfixable?).to be(true)
    end

    it "is true when the ongoing release production rollout is halted" do
      _completed_release = create(:release, :finished, train:)
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:)
      release_platform_run = create(:release_platform_run, release: ongoing_release, release_platform: train.release_platforms.sole)
      production_release = create(:production_release, :active, release_platform_run:, build: create(:build))
      create(:play_store_submission, :prepared, parent_release: production_release)
      create(:store_rollout, :halted, release_platform_run:, store_submission: production_release.store_submission)
      expect(train.reload.hotfixable?).to be(true)
    end

    it "is true when the ongoing release production rollout is paused" do
      _completed_release = create(:release, :finished, train:)
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:)
      release_platform_run = create(:release_platform_run, release: ongoing_release, release_platform: train.release_platforms.sole)
      production_release = create(:production_release, :active, release_platform_run:, build: create(:build))
      create(:play_store_submission, :prepared, parent_release: production_release)
      create(:store_rollout, :paused, release_platform_run:, store_submission: production_release.store_submission)
      expect(train.reload.hotfixable?).to be(true)
    end

    it "is true when the ongoing release is not being actively rolled out" do
      _completed_release = create(:release, :finished, train:)
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:)
      release_platform_run = create(:release_platform_run, release: ongoing_release, release_platform: train.release_platforms.first)
      create(:production_release, :inflight, release_platform_run:, build: create(:build))
      expect(train.reload.hotfixable?).to be(true)
    end

    it "is true when the ongoing release is in stability stage" do
      _completed_release = create(:release, :finished, train:)
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:)
      create(:release_platform_run, release: ongoing_release, release_platform: train.release_platforms.sole)
      expect(train.reload.hotfixable?).to be(true)
    end
  end

  describe "#stop_failed_ongoing_release!" do
    it "does nothing if teh train is not automatic" do
      train = create(:train, :active, stop_automatic_releases_on_failure: true)
      release = create(:release, :post_release_failed, train:)

      train.stop_failed_ongoing_release!

      expect(release.reload.stopped?).to be(false)
    end

    it "does nothing if the ongoing release is not in failed state" do
      train = create(:train, :active, :with_schedule, stop_automatic_releases_on_failure: true)
      release = create(:release, :on_track, train:)

      train.stop_failed_ongoing_release!

      expect(release.reload.stopped?).to be(false)
    end

    it "does nothing if the flag to stop release is not enabled" do
      train = create(:train, :active, :with_schedule, stop_automatic_releases_on_failure: false)
      release = create(:release, :post_release_failed, train:)

      train.stop_failed_ongoing_release!

      expect(release.reload.stopped?).to be(false)
    end

    it "stops the ongoing release which is in failed state" do
      train = create(:train, :active, :with_schedule, stop_automatic_releases_on_failure: true)
      release = create(:release, :on_track, :with_no_platform_runs, train:)
      release_platform_run = create(:release_platform_run, release:)
      _beta_release = create(:beta_release, :failed, release_platform_run:)

      train.stop_failed_ongoing_release!

      expect(release.failure_anywhere?).to be(true)
      expect(release.reload.stopped?).to be(true)
    end
  end

  describe "release_branch_pattern validation" do
    it "is valid when pattern is blank" do
      train = build(:train, release_branch_pattern: "")
      expect(train).to be_valid
    end

    it "is valid when pattern is nil" do
      train = build(:train, release_branch_pattern: nil)
      expect(train).to be_valid
    end

    it "is valid with correct pattern format" do
      train = build(:train, release_branch_pattern: "release/~trainName~/%Y-%m-%d")
      expect(train).to be_valid
    end

    it "is valid with pattern containing various strftime formats" do
      train = build(:train, release_branch_pattern: "r/~trainName~/%Y-%m-%d-%H%M%S")
      expect(train).to be_valid
    end

    it "is valid with releaseVersion token" do
      train = build(:train, release_branch_pattern: "r/~trainName~/~releaseVersion~")
      expect(train).to be_valid
    end

    it "is valid with releaseStartDate token" do
      train = build(:train, release_branch_pattern: "r/~trainName~/~releaseStartDate~")
      expect(train).to be_valid
    end

    it "is valid with multiple tokens and strftime" do
      train = build(:train, release_branch_pattern: "r/~trainName~/~releaseVersion~/~releaseStartDate~/%Y-%m-%d")
      expect(train).to be_valid
    end

    it "is valid when pattern has no tokens" do
      train = build(:train, release_branch_pattern: "release/myapp/%Y-%m-%d")
      expect(train).to be_valid
    end

    it "is not valid when pattern has invalid tokens" do
      train = build(:train, release_branch_pattern: "release/~invalidToken~")
      expect(train).not_to be_valid
      expect(train.errors[:release_branch_pattern]).to include("contains unknown tokens: ~invalidToken~")
    end
  end

  describe "version config constraints validations" do
    it "is valid when neither freeze_version nor patch_version_bump_only is true" do
      train = build(:train, freeze_version: false, patch_version_bump_only: false)
      expect(train).to be_valid
    end

    it "is valid when only freeze_version is true" do
      train = build(:train, freeze_version: true, patch_version_bump_only: false)
      expect(train).to be_valid
    end

    it "is valid when only patch_version_bump_only is true" do
      train = build(:train, freeze_version: false, patch_version_bump_only: true)
      expect(train).to be_valid
    end

    it "is not valid when both freeze_version and patch_version_bump_only are true" do
      train = build(:train, freeze_version: true, patch_version_bump_only: true)
      expect(train).not_to be_valid
      expect(train.errors[:base]).to include("both freeze_version and patch_version_bump_only cannot be true at the same time")
    end
  end

  describe "#last_finished_release" do
    let(:train) { create(:train, :active) }
    let!(:finished_releases) { create_list(:release, 2, :finished, train:) }

    it "returns last finished release" do
      expect(train.last_finished_release).to eq(finished_releases.second)
    end
  end

  describe "#previous_releases" do
    let(:train) { create(:train, :active) }
    let!(:finished_releases) { create_list(:release, 5, :finished, train:) }

    it "returns all but last finished release" do
      expect(train.previous_releases).to match_array(finished_releases[0..3])
    end
  end
end
