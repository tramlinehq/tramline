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

  describe "#populate_release_schedules" do
    let(:train) { create(:train, status: :active, kickoff_at: 7.hours.from_now, repeat_duration: 1.day) }

    context "when updating schedule with existing scheduled releases" do
      before do
        # Create existing scheduled releases
        create(:scheduled_release, train: train, scheduled_at: 8.hours.from_now)
        create(:scheduled_release, train: train, scheduled_at: 1.day.from_now)
      end

      it "discards existing scheduled releases and creates new one from kickoff_at" do
        expect(train.scheduled_releases.count).to eq(2)

        # Update kickoff_at to trigger populate_release_schedules
        new_kickoff = 9.hours.from_now
        train.update!(kickoff_at: new_kickoff)

        # Should have discarded old ones and created one new one
        expect(train.scheduled_releases.kept.count).to eq(1)
        expect(train.scheduled_releases.unscoped.discarded.count).to eq(2)

        # New schedule should be based on updated kickoff_at_app_time (timezone-aware)
        new_scheduled_release = train.scheduled_releases.kept.first
        expect(new_scheduled_release.scheduled_at).to eq(train.kickoff_at_app_time)
      end

      it "calculates next run correctly within transaction" do
        # Mock to verify transaction behavior
        allow(train).to receive(:next_run_at).and_call_original

        _old_kickoff = train.kickoff_at
        new_kickoff = 2.days.from_now

        train.update!(kickoff_at: new_kickoff)

        # Should have called next_run_at after discarding
        expect(train).to have_received(:next_run_at)

        # Verify the scheduled release uses new kickoff time (timezone-aware)
        new_scheduled_release = train.scheduled_releases.kept.first
        expect(new_scheduled_release.scheduled_at).to eq(train.kickoff_at_app_time)
      end
    end

    context "when kickoff_at is in the past" do
      it "prevents setting kickoff_at to a past time" do
        past_kickoff = 2.hours.ago

        expect {
          train.update!(kickoff_at: past_kickoff)
        }.to raise_error(ActiveRecord::RecordInvalid, /the schedule kickoff should be in the future/)
      end
    end

    context "when train is not automatic" do
      let(:train) { create(:train, status: :draft, kickoff_at: nil, repeat_duration: nil) }

      it "does not create scheduled releases" do
        expect { train.update!(name: "Updated") }.not_to change(ScheduledRelease, :count)
      end
    end

    context "when updating attributes other than schedule" do
      before do
        # Create some initial scheduled releases
        create(:scheduled_release, train: train, scheduled_at: 8.hours.from_now)
        create(:scheduled_release, train: train, scheduled_at: 1.day.from_now)
      end

      it "does not repopulate scheduled releases" do
        expect(train.scheduled_releases.count).to eq(2)

        original_count = train.scheduled_releases.count
        original_scheduled_at = train.scheduled_releases.first.scheduled_at

        # Update non-schedule attributes
        train.update!(name: "Updated Name", description: "Updated Description")

        # Should not have changed scheduled releases
        expect(train.scheduled_releases.count).to eq(original_count)
        expect(train.scheduled_releases.first.scheduled_at).to eq(original_scheduled_at)
      end
    end
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
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(train.kickoff_at_app_time)
    end
  end

  describe "#next_run_at" do
    it "returns kickoff time if no releases have been scheduled yet and kickoff is in the future" do
      train = create(:train, :with_schedule, :active)

      expect(train.next_run_at).to eq(train.kickoff_at_app_time)
    end

    it "returns kickoff + repeat duration time if no releases have been scheduled yet and kickoff is in the past" do
      train = create(:train, :with_schedule, :active)

      travel_to train.kickoff_at_app_time + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at_app_time + train.repeat_duration)
      end
    end

    it "returns next available schedule time if there is a scheduled release" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at_app_time)

      travel_to train.kickoff_at_app_time + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at_app_time + train.repeat_duration)
      end
    end

    it "returns next available schedule time if there are many scheduled releases" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at_app_time)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at_app_time + train.repeat_duration)

      travel_to train.kickoff_at_app_time + 1.day + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at_app_time + train.repeat_duration * 2)
      end
    end

    it "returns next available schedule time if there are scheduled releases and more than repeat duration has passed since last scheduled release" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at_app_time)

      travel_to train.kickoff_at_app_time + 2.days + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at_app_time + train.repeat_duration * 3)
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
      expect(train.scheduled_releases.count).to eq(0)

      train.update!(kickoff_at: 2.days.from_now, repeat_duration: 2.days)

      expect(train.reload.scheduled_releases.count).to eq(1)
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(train.kickoff_at_app_time)
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

  describe "soak period validations" do
    context "when soak_period_enabled is true" do
      it "validates presence of soak_period_hours" do
        train = build(:train, soak_period_enabled: true, soak_period_hours: nil)
        expect(train).not_to be_valid
        expect(train.errors[:soak_period_hours]).to include("can't be blank")
      end

      it "validates soak_period_hours is greater than 0" do
        train = build(:train, soak_period_enabled: true, soak_period_hours: 0)
        expect(train).not_to be_valid
        expect(train.errors[:soak_period_hours]).to include("must be greater than 0")
      end

      it "validates soak_period_hours is less than or equal to 336" do
        train = build(:train, soak_period_enabled: true, soak_period_hours: 337)
        expect(train).not_to be_valid
        expect(train.errors[:soak_period_hours]).to include("must be less than or equal to 336")
      end

      it "is valid with soak_period_hours between 1 and 168" do
        train = build(:train, soak_period_enabled: true, soak_period_hours: 24)
        expect(train).to be_valid
      end

      it "is valid with soak_period_hours at minimum boundary (1)" do
        train = build(:train, soak_period_enabled: true, soak_period_hours: 1)
        expect(train).to be_valid
      end

      it "is valid with soak_period_hours at maximum boundary (168)" do
        train = build(:train, soak_period_enabled: true, soak_period_hours: 168)
        expect(train).to be_valid
      end
    end

    context "when soak_period_enabled is false" do
      it "does not validate soak_period_hours" do
        train = build(:train, soak_period_enabled: false, soak_period_hours: nil)
        expect(train).to be_valid
      end

      it "is valid with out-of-range soak_period_hours when disabled" do
        train = build(:train, soak_period_enabled: false, soak_period_hours: 200)
        expect(train).to be_valid
      end
    end
  end

  describe "build queue validations" do
    let(:train) { create(:train, :active) }

    describe "when build_queue_enabled changes and releases are running" do
      before do
        # Create an active run
        create(:release, :on_track, train: train)
      end

      it "prevents enabling build queue when releases are running" do
        train.build_queue_enabled = true
        train.build_queue_size = 5
        train.build_queue_wait_time = 1.hour

        expect(train).not_to be_valid
        expect(train.errors[:build_queue_enabled]).to include("build queue cannot be enabled/disabled when releases are running")
      end

      it "prevents disabling build queue when releases are running" do
        # Create a train with build queue already enabled (without active runs)
        train_with_queue = create(:train, :active, build_queue_enabled: true, build_queue_size: 5, build_queue_wait_time: 1.hour)

        # Now create an active run
        create(:release, :on_track, train: train_with_queue)

        # Try to disable it
        train_with_queue.build_queue_enabled = false

        expect(train_with_queue).not_to be_valid
        expect(train_with_queue.errors[:build_queue_enabled]).to include("build queue cannot be enabled/disabled when releases are running")
      end

      it "allows other changes when build_queue_enabled doesn't change" do
        # Create a train with build queue already enabled (without active runs)
        train_with_queue = create(:train, :active, build_queue_enabled: true, build_queue_size: 5, build_queue_wait_time: 1.hour)

        # Now create an active run
        create(:release, :on_track, train: train_with_queue)

        # Change other attributes but not build_queue_enabled
        train_with_queue.build_queue_size = 10
        train_with_queue.name = "Updated Train Name"

        expect(train_with_queue).to be_valid
      end
    end

    describe "when no releases are running" do
      it "allows enabling build queue" do
        train.build_queue_enabled = true
        train.build_queue_size = 5
        train.build_queue_wait_time = 1.hour

        expect(train).to be_valid
      end

      it "allows disabling build queue" do
        # First enable build queue
        train.update!(build_queue_enabled: true, build_queue_size: 5, build_queue_wait_time: 1.hour)

        # Now disable it (and clear the config to avoid validation errors)
        train.build_queue_enabled = false
        train.build_queue_size = nil
        train.build_queue_wait_time = nil

        expect(train).to be_valid
      end
    end

    describe "when releases exist but are not active" do
      before do
        # Create finished releases (not active runs)
        create(:release, :finished, train: train)
        create(:release, :stopped, train: train)
      end

      it "allows changing build queue settings" do
        train.build_queue_enabled = true
        train.build_queue_size = 5
        train.build_queue_wait_time = 1.hour

        expect(train).to be_valid
      end
    end
  end

  describe "DST-safe scheduling behavior" do
    let(:app) { create(:app, :android, timezone: "America/New_York") } # EST/EDT timezone
    let(:train) { create(:train, app: app) }

    describe "#kickoff_at_app_time" do
      it "interprets naive datetime in app timezone" do
        travel_to Time.zone.parse("2024-07-15 10:00:00") do
          train.update!(kickoff_at: "2024-07-15 14:30:00", repeat_duration: 1.week)

          result = train.kickoff_at_app_time

          expect(result.hour).to eq(14)
          expect(result.min).to eq(30)
          expect(result.zone).to eq("EDT")
        end
      end

      it "returns nil when kickoff_at is nil" do
        train.update!(kickoff_at: nil)
        expect(train.kickoff_at_app_time).to be_nil
      end

      it "uses app timezone for interpretation" do
        pacific_app = create(:app, :android, timezone: "America/Los_Angeles")
        pacific_train = create(:train, app: pacific_app)

        travel_to Time.zone.parse("2024-07-15 10:00:00") do
          pacific_train.update!(kickoff_at: "2024-07-15 14:30:00", repeat_duration: 1.week)
          result = pacific_train.kickoff_at_app_time
          expect(result.zone).to eq("PDT")
        end
      end
    end

    describe "maintains consistent local time across DST transitions" do
      it "keeps the same hour during spring DST transition (EST -> EDT)" do
        # Set schedule before spring transition
        travel_to Time.zone.parse("2024-03-01 10:00:00") do
          # EST
          train.update!(kickoff_at: "2024-03-01 14:00:00", repeat_duration: 1.week) # 2 PM EST
        end

        # Check before transition - should be 2 PM in EST
        travel_to Time.zone.parse("2024-03-01 10:00:00") do
          result = train.kickoff_at_app_time
          expect(result.hour).to eq(14) # Same local hour
          expect(result.zone).to eq("EST") # Timezone reflects the date context
        end

        # Check after DST transition - should still be 2 PM
        # Note: timezone reflects the stored date (March 1 = EST), not current date
        travel_to Time.zone.parse("2024-03-15 10:00:00") do
          # After DST spring forward
          result = train.kickoff_at_app_time
          expect(result.hour).to eq(14) # Same local hour maintained!
          expect(result.zone).to eq("EST") # Zone based on stored date (March 1)
        end
      end

      it "keeps the same hour during fall DST transition (EDT -> EST)" do
        # Set schedule during EDT
        travel_to Time.zone.parse("2024-10-01 10:00:00") do
          # EDT
          train.update!(kickoff_at: "2024-10-01 14:00:00", repeat_duration: 1.week) # 2 PM EDT
        end

        # Check before transition - should be 2 PM in EDT
        travel_to Time.zone.parse("2024-10-01 10:00:00") do
          result = train.kickoff_at_app_time
          expect(result.hour).to eq(14) # Same local hour
          expect(result.zone).to eq("EDT") # Timezone reflects the date context
        end

        # Check after DST fall back - should still be 2 PM
        # Note: timezone reflects the stored date (October 1 = EDT), not current date
        travel_to Time.zone.parse("2024-11-15 10:00:00") do
          # After DST ends
          result = train.kickoff_at_app_time
          expect(result.hour).to eq(14) # Same local hour maintained!
          expect(result.zone).to eq("EDT") # Zone based on stored date (October 1)
        end
      end
    end

    describe "#next_run_at maintains local time across DST transitions" do
      it "maintains same local hour when crossing fall DST (clocks fall back)" do
        # DST ends Nov 3, 2024 at 2am in America/New_York (EDT -> EST)
        # Schedule: 6pm daily
        # EDT is UTC-4, so 6pm EDT = 10pm UTC
        travel_to Time.zone.parse("2024-11-02 14:00:00") do
          # 10am EDT
          train.update!(kickoff_at: "2024-11-02 18:00:00", repeat_duration: 1.day)
        end

        # Current time after kickoff: 11pm UTC = 7pm EDT (after 6pm EDT kickoff)
        travel_to Time.zone.parse("2024-11-02 23:00:00") do
          next_run = train.next_run_at

          # Should be Nov 3, 6pm EST (not 5pm or 7pm)
          expect(next_run.hour).to eq(18)
          expect(next_run.day).to eq(3)
          expect(next_run.zone).to eq("EST") # Now in EST after DST ended
        end
      end

      it "maintains same local hour when crossing spring DST (clocks spring forward)" do
        # DST starts Mar 10, 2024 at 2am in America/New_York (EST -> EDT)
        # Schedule: 6pm daily
        # EST is UTC-5, so 6pm EST = 11pm UTC
        travel_to Time.zone.parse("2024-03-09 15:00:00") do
          # 10am EST
          train.update!(kickoff_at: "2024-03-09 18:00:00", repeat_duration: 1.day)
        end

        # Current time after kickoff: midnight UTC = 7pm EST (after 6pm EST kickoff)
        travel_to Time.zone.parse("2024-03-10 00:00:00") do
          next_run = train.next_run_at

          # Should be Mar 10, 6pm EDT (not 5pm or 7pm)
          expect(next_run.hour).to eq(18)
          expect(next_run.day).to eq(10)
          expect(next_run.zone).to eq("EDT") # Now in EDT after DST started
        end
      end

      # rubocop:disable RSpec/MultipleExpectations
      it "maintains local time across multiple DST transitions with scheduled_releases" do
        # Start before fall DST, create a scheduled release, then check after DST
        # Oct 26 is still EDT (UTC-4), 6pm EDT = 10pm UTC
        travel_to Time.zone.parse("2024-10-26 14:00:00") do
          # 10am EDT
          train.update!(kickoff_at: "2024-10-26 18:00:00", repeat_duration: 1.week)
          # Create first scheduled release (stored as UTC in DB)
          train.scheduled_releases.create!(scheduled_at: train.kickoff_at_app_time)
        end

        # After first kickoff: 11pm UTC = 7pm EDT
        travel_to Time.zone.parse("2024-10-26 23:00:00") do
          next_run = train.next_run_at

          # Should be Nov 2, 6pm EDT (still EDT, DST hasn't ended yet)
          expect(next_run.hour).to eq(18)
          expect(next_run.month).to eq(11)
          expect(next_run.day).to eq(2)
        end

        # Create scheduled release for Nov 2 and check next week
        # Nov 2 is still EDT, 6pm EDT = 10pm UTC
        travel_to Time.zone.parse("2024-11-02 23:00:00") do
          # 7pm EDT
          train.scheduled_releases.create!(scheduled_at: train.next_run_at)
        end

        # After DST ended (Nov 3), check next run
        # Nov 9 is EST (UTC-5), 6pm EST = 11pm UTC
        travel_to Time.zone.parse("2024-11-03 15:00:00") do
          # 10am EST
          next_run = train.next_run_at

          # Should be Nov 9, 6pm EST (DST ended, now EST)
          expect(next_run.hour).to eq(18)
          expect(next_run.month).to eq(11)
          expect(next_run.day).to eq(9)
          expect(next_run.zone).to eq("EST")
        end
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    describe "#last_run_at uses kickoff_at_app_time" do
      it "returns timezone-aware kickoff_at_app_time when no scheduled releases" do
        travel_to Time.zone.parse("2024-07-15 10:00:00") do
          train.update!(kickoff_at: "2024-07-15 14:30:00", repeat_duration: 1.week)

          # Test that last_run_at uses kickoff_at_app_time method
          expect(train.last_run_at).to eq(train.kickoff_at_app_time)
          # Test that kickoff_at_app_time returns timezone-aware time
          expect(train.kickoff_at_app_time.zone).to eq("EDT")
        end
      end
    end

    describe "validation uses kickoff_at_app_time for future time check" do
      it "correctly validates future times" do
        travel_to Time.zone.parse("2024-01-15 10:00:00") do
          train.assign_attributes(
            kickoff_at: "2024-01-15 15:00:00", # 3 PM same day (future)
            repeat_duration: 1.day
          )

          expect(train).to be_valid
        end
      end

      it "correctly rejects past times" do
        # 21:00 UTC = 16:00 EST (4 PM in America/New_York)
        travel_to Time.zone.parse("2024-01-15 21:00:00") do
          train.assign_attributes(
            # 15:00 EST = 20:00 UTC, which is before 21:00 UTC (current time)
            kickoff_at: "2024-01-15 15:00:00",
            repeat_duration: 1.day
          )

          expect(train).not_to be_valid
          expect(train.errors[:kickoff_at]).to include("the schedule kickoff should be in the future")
        end
      end
    end
  end
end
