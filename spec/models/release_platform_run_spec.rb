require "rails_helper"
using RefinedString

describe ReleasePlatformRun do
  it "has a valid factory" do
    expect(create(:release_platform_run)).to be_valid
  end

  describe ".create" do
    it "creates the release metadata with default locale" do
      run = create(:release_platform_run)
      expect(run.default_release_metadata).to be_present
      expect(run.default_release_metadata.locale).to eq(ReleaseMetadata::DEFAULT_LOCALE)
      expect(run.default_release_metadata.release_notes).to eq(ReleaseMetadata::DEFAULT_RELEASE_NOTES)
    end

    it "creates the release metadata with active_locales" do
      app = create(:app, :android)
      train = create(:train, app:)
      create(:external_app, :android, app:)
      release = create(:release, train: train)
      release_platform = create(:release_platform, train:)
      run = create(:release_platform_run, release:, release_platform:)

      expect(run.default_release_metadata.locale).to eq("en-US")
      expect(run.default_release_metadata.release_notes).to eq("This latest version includes bugfixes for the android platform.")
      expect(run.release_metadata.size).to eq(1)
      expect(run.release_metadata.pluck(:locale)).to contain_exactly("en-US")
    end
  end

  describe "#version_bump_required?" do
    let(:release) { create(:release, :with_no_platform_runs) }
    let(:run_version) { "1.2.0" }
    let(:release_platform_run) { create(:release_platform_run, release:, release_version: run_version) }

    it "is false when it does not have a production release" do
      expect(release_platform_run.version_bump_required?).not_to be(true)
    end

    it "is true when production release requires a version bump" do
      build = create(:build, release_platform_run:, version_name: run_version)
      create(:production_release, release_platform_run:, status: :active, build:)
      expect(release_platform_run.version_bump_required?).to be(true)
    end
  end

  describe "#bump_version!" do
    it "updates the minor version if the current version is a partial semver" do
      release_version = "1.2"
      release = create(:release, :with_no_platform_runs)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_version:)
      build = create(:build, release_platform_run:, version_name: release_version)
      _production_release = create(:production_release, :active, build:, release_platform_run:)

      release_platform_run.bump_version!
      expect(release_platform_run.release_version).to eq("1.3")
    end

    it "updates the patch version if the current version is a proper semver" do
      release_version = "1.2.3"
      release = create(:release, :with_no_platform_runs)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_version:)
      build = create(:build, release_platform_run:, version_name: release_version)
      _production_release = create(:production_release, :active, build:, release_platform_run:)

      release_platform_run.bump_version!
      expect(release_platform_run.release_version).to eq("1.2.4")
    end

    it "does not bump version if there are no production release" do
      release_version = "1.2.3"
      release = create(:release, :with_no_platform_runs)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_version:)

      expect {
        release_platform_run.bump_version!
      }.not_to change { release_platform_run.release_version }
    end

    context "when upcoming release and proper semver" do
      let(:ongoing_release_version) { "1.2.3" }
      let(:upcoming_release_version) { "1.3.0" }
      let(:train) { create(:train, :with_no_platforms) }
      let(:release_platform) { create(:release_platform, train:) }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }
      let(:upcoming_release) { create(:release, :with_no_platform_runs, train:, original_release_version: upcoming_release_version) }

      it "bumps patch version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)
        _upcoming_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: upcoming_release, release_version: upcoming_release_version)
        build = create(:build, release_platform_run: ongoing_release_platform_run, version_name: ongoing_release_version)
        _production_release = create(:production_release, :active, build:, release_platform_run: ongoing_release_platform_run)

        ongoing_release_platform_run.bump_version!

        expect(ongoing_release_platform_run.reload.release_version).to eq("1.2.4")
      end
    end

    context "when upcoming release and partial semver" do
      let(:ongoing_release_version) { "1.2" }
      let(:upcoming_release_version) { "1.3" }
      let(:train) { create(:train, :with_no_platforms) }
      let(:release_platform) { create(:release_platform, train:) }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }
      let(:upcoming_release) { create(:release, :with_no_platform_runs, train:, original_release_version: upcoming_release_version) }

      it "bumps version to higher than current upcoming release version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)
        _upcoming_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: upcoming_release, release_version: upcoming_release_version)
        build = create(:build, release_platform_run: ongoing_release_platform_run, version_name: ongoing_release_version)
        _production_release = create(:production_release, :active, build:, release_platform_run: ongoing_release_platform_run)

        ongoing_release_platform_run.bump_version!

        expect(ongoing_release_platform_run.reload.release_version).to eq("1.4")
      end
    end

    context "when no upcoming release and partial semver" do
      let(:ongoing_release_version) { "1.2" }
      let(:train) { create(:train, :with_no_platforms) }
      let(:release_platform) { create(:release_platform, train:) }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }

      it "bumps version to next release version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)
        build = create(:build, release_platform_run: ongoing_release_platform_run, version_name: ongoing_release_version)
        _production_release = create(:production_release, :active, build:, release_platform_run: ongoing_release_platform_run)

        ongoing_release_platform_run.bump_version!
        ongoing_release_platform_run.reload

        expect(ongoing_release_platform_run.release_version).to eq("1.3")
      end
    end
  end

  describe "#correct_version!" do
    let(:app) { create(:app, :android) }
    let(:train) { create(:train, app:, version_seeded_with: "1.1") }
    let(:release_platform) { create(:release_platform, train:) }

    context "when ongoing release has moved on" do
      let(:ongoing_release_version) { "1.2" }
      let(:upcoming_release_version) { "1.3" }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }
      let(:upcoming_release) { create(:release, :with_no_platform_runs, train:, original_release_version: upcoming_release_version) }

      it "updates version to surpass ongoing release version" do
        _ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: "1.4")
        upcoming_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: upcoming_release, release_version: upcoming_release_version)

        upcoming_release_platform_run.correct_version!
        upcoming_release_platform_run.reload

        expect(upcoming_release_platform_run.release_version).to eq("1.5")
      end
    end

    context "when train version current has moved on" do
      let(:ongoing_release_version) { "1.2" }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }

      it "updates version to surpass ongoing release version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)
        train.update!(version_current: "1.3")

        ongoing_release_platform_run.correct_version!
        ongoing_release_platform_run.reload

        expect(ongoing_release_platform_run.release_version).to eq("1.4")
      end
    end

    context "when hotfix release has started" do
      let(:ongoing_release_version) { "1.2" }
      let(:hotfix_release_version) { "1.2" }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }
      let(:hotfix_release) { create(:release, :with_no_platform_runs, :hotfix, train:, original_release_version: hotfix_release_version) }

      it "updates version to surpass hotfix release version" do
        _hotfix_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: hotfix_release, release_version: "1.3")
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)

        ongoing_release_platform_run.correct_version!
        ongoing_release_platform_run.reload

        expect(ongoing_release_platform_run.release_version).to eq("1.4")
      end
    end
  end

  describe "#available_rc_builds" do
    let(:release_platform_run) { create(:release_platform_run) }

    it "returns rc builds without production releases" do
      build = create(:build, :rc, release_platform_run:)

      expect(release_platform_run.available_rc_builds).to include(build)
    end

    it "excludes builds with production releases" do
      build = create(:build, :rc, release_platform_run:)
      create(:production_release, release_platform_run:, build:)

      expect(release_platform_run.available_rc_builds).not_to include(build)
    end

    context "with after parameter" do
      it "returns only builds generated after the given build" do
        older_build = create(:build, :rc, release_platform_run:, generated_at: 2.hours.ago)
        newer_build = create(:build, :rc, release_platform_run:, generated_at: 1.hour.ago)

        expect(release_platform_run.available_rc_builds(after: older_build)).to include(newer_build)
        expect(release_platform_run.available_rc_builds(after: older_build)).not_to include(older_build)
      end

      it "excludes the reference build itself" do
        build = create(:build, :rc, release_platform_run:)

        expect(release_platform_run.available_rc_builds(after: build)).not_to include(build)
      end

      context "when combined with version filtering" do
        let(:train) { create(:train, :with_no_platforms) }
        let(:release_platform) { create(:release_platform, platform: "ios", train:) }
        let(:release) { create(:release, :with_no_platform_runs, train:) }
        let(:release_platform_run) { create(:release_platform_run, release_platform:, release:, release_version: "10.44.0") }

        it "filters by both time and version" do
          # Build with version 10.44.0
          active_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Bump version to 10.44.1
          release_platform_run.update!(release_version: "10.44.1")

          # Create multiple builds at 10.44.1
          build_1 = create(:build, :rc, release_platform_run:, generated_at: 3.hours.ago)
          build_2 = create(:build, :rc, release_platform_run:, generated_at: 2.hours.ago)
          build_3 = create(:build, :rc, release_platform_run:, generated_at: 1.hour.ago)

          # Get builds after build_1 (should only include build_2 and build_3)
          available = release_platform_run.available_rc_builds(after: build_1)
          expect(available).not_to include(build_1)
          expect(available).to include(build_2)
          expect(available).to include(build_3)
          expect(available.count).to eq(2)
        end
      end
    end

    context "with version filtering" do
      let(:train) { create(:train, :with_no_platforms) }
      let(:release_platform) { create(:release_platform, platform: "ios", train:) }
      let(:release) { create(:release, :with_no_platform_runs, train:) }
      let(:release_platform_run) { create(:release_platform_run, release_platform:, release:, release_version: "10.44.0") }

      it "includes all builds when no production release" do
        # Two builds with the same version (both should be available)
        build_1 = create(:build, :rc, release_platform_run:)
        build_2 = create(:build, :rc, release_platform_run:)

        available = release_platform_run.available_rc_builds
        expect(available).to include(build_1)
        expect(available).to include(build_2)
      end

      context "with active production release" do
        it "excludes builds with version <= active rollout version" do
          # Build with version 10.44.0 (created when run was at 10.44.0)
          active_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Another build with same version 10.44.0 (should be excluded)
          older_build = create(:build, :rc, release_platform_run:, generated_at: 1.day.ago)

          # Bump version to 10.44.1 (simulating version bump after approval)
          release_platform_run.update!(release_version: "10.44.1")

          # New build with version 10.44.1 (should be included)
          newer_build = create(:build, :rc, release_platform_run:, generated_at: 1.hour.ago)

          available = release_platform_run.available_rc_builds
          expect(available).not_to include(older_build)
          expect(available).to include(newer_build)
        end

        it "includes multiple newer builds as patch fix options" do
          # Build with version 10.44.0 (created when run was at 10.44.0)
          active_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Bump version to 10.44.1 (simulating version bump after approval)
          release_platform_run.update!(release_version: "10.44.1")

          # Multiple new builds with version 10.44.1 (all should be included as patch fix options)
          patch_build_1 = create(:build, :rc, release_platform_run:, generated_at: 3.hours.ago)
          patch_build_2 = create(:build, :rc, release_platform_run:, generated_at: 2.hours.ago)
          patch_build_3 = create(:build, :rc, release_platform_run:, generated_at: 1.hour.ago)

          available = release_platform_run.available_rc_builds
          expect(available).to include(patch_build_1)
          expect(available).to include(patch_build_2)
          expect(available).to include(patch_build_3)
          expect(available.count).to eq(3)
        end

        it "handles partial semver comparison" do
          # Start with partial semver version 10.44
          release_platform_run.update!(release_version: "10.44")

          # Build with version 10.44 (partial semver)
          active_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Another build with same version 10.44 (should be excluded)
          older_build = create(:build, :rc, release_platform_run:, generated_at: 1.day.ago)

          # Bump version to 10.45 (partial semver)
          release_platform_run.update!(release_version: "10.45")

          # New build with version 10.45 (should be included)
          newer_build = create(:build, :rc, release_platform_run:)

          available = release_platform_run.available_rc_builds
          expect(available).not_to include(older_build)
          expect(available).to include(newer_build)
        end
      end

      context "with finished production release" do
        it "filters against finished production release when no active release" do
          # Build with version 10.44.0
          finished_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :finished, release_platform_run:, build: finished_build)

          # Another build with same version 10.44.0 (should be excluded)
          older_build = create(:build, :rc, release_platform_run:, generated_at: 1.day.ago)

          # Bump version to 10.44.1
          release_platform_run.update!(release_version: "10.44.1")

          # New build with version 10.44.1 (should be included)
          newer_build = create(:build, :rc, release_platform_run:)

          available = release_platform_run.available_rc_builds
          expect(available).not_to include(older_build)
          expect(available).to include(newer_build)
        end

        it "prefers active production release over finished when both exist" do
          # Build with version 10.44.0 (finished)
          finished_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :finished, release_platform_run:, build: finished_build)

          # Bump version to 10.44.1
          release_platform_run.update!(release_version: "10.44.1")

          # Build with version 10.44.1 (active)
          active_build = create(:build, :rc, release_platform_run:)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Build with version 10.44.0 (should be excluded based on finished release)
          old_build = create(:build, :rc, release_platform_run:)
          old_build.update!(version_name: "10.44.0")

          # Bump version to 10.44.2
          release_platform_run.update!(release_version: "10.44.2")

          # New build with version 10.44.2 (should be included)
          newer_build = create(:build, :rc, release_platform_run:)

          available = release_platform_run.available_rc_builds
          # Should filter based on active (10.44.1), not finished (10.44.0)
          # So 10.44.2 > 10.44.1, should be included
          expect(available).to include(newer_build)
          expect(available.count).to eq(1)
        end
      end
    end
  end

  describe ".previously_completed_rollout_run" do
    let(:train) { create(:train) }

    it "returns nil when there is no previous rollout run" do
      release_platform = create(:release_platform, train:)
      release = create(:release, :finished, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      expect(release_platform_run.previously_completed_rollout_run).to be_nil
    end

    it "returns nil if the previous one is another platform" do
      ios_platform = create(:release_platform, platform: "ios", train:)
      previous_release = create(:release, :finished, train:)
      previous_run = create(:release_platform_run, :finished, release_platform: ios_platform, release: previous_release)
      previous_store_submission = create(:app_store_submission, release_platform_run: previous_run)
      _previous_rollout = create(:store_rollout, :completed, type: "AppStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

      android_platform = create(:release_platform, platform: "android", train:)
      release = create(:release, :on_track, train:)
      release_platform_run = create(:release_platform_run, release_platform: android_platform, release:)
      store_submission = create(:play_store_submission, release_platform_run:)
      _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

      expect(release_platform_run.previously_completed_rollout_run).to be_nil
    end

    context "when previous run might be present" do
      let(:release_platform) { create(:release_platform, train:) }
      let(:previous_release) { create(:release, :finished, train:) }
      let(:previous_run) { create(:release_platform_run, :finished, release_platform:, release: previous_release) }
      let(:previous_parent_release) { create(:production_release, :finished, release_platform_run: previous_run) }
      let(:previous_store_submission) { create(:play_store_submission, parent_release: previous_parent_release, release_platform_run: previous_run) }

      it "returns nil for incomplete production store rollouts" do
        _previous_rollout = create(:store_rollout, :paused, type: "PlayStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to be_nil
      end

      it "returns the previous rollout run when there is a previous rollout run" do
        _previous_rollout = create(:store_rollout, :completed, :last_but_not_hundred, type: "PlayStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to eq(previous_run)
      end

      it "does not return rollouts that are fully_released" do
        _previous_rollout = create(:store_rollout, :fully_released, type: "PlayStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to be_nil
      end

      it "returns the last known good run with a completed prod rollout" do
        _previous_rollout = create(:store_rollout, :completed, :last_but_not_hundred, type: "PlayStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

        last_release = create(:release, :finished, train:)
        last_run = create(:release_platform_run, :stopped, release_platform:, release: last_release)
        last_parent_release = create(:production_release, :finished, release_platform_run: last_run)
        last_store_submission = create(:play_store_submission, parent_release: last_parent_release, release_platform_run: last_run)
        _last_rollout = create(:store_rollout, :paused, :last_but_not_hundred, type: "PlayStoreRollout", release_platform_run: last_run, store_submission: last_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to eq(previous_run)
      end

      it "considers the last known good run regardless of the status of the release or platform run" do
        release_platform = create(:release_platform, train:)

        previous_release = create(:release, :finished, train:)
        previous_run = create(:release_platform_run, :finished, release_platform:, release: previous_release, completed_at: Time.current - 2)
        previous_parent_release = create(:production_release, :finished, release_platform_run: previous_run)
        previous_store_submission = create(:play_store_submission, parent_release: previous_parent_release, release_platform_run: previous_run)
        _previous_rollout = create(:store_rollout, :completed, :last_but_not_hundred, type: "PlayStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

        last_release = create(:release, :stopped, train:)
        last_run = create(:release_platform_run, :stopped, release_platform:, release: last_release, scheduled_at: Time.current - 1)
        last_parent_release = create(:production_release, :finished, release_platform_run: last_run)
        last_store_submission = create(:play_store_submission, parent_release: last_parent_release, release_platform_run: last_run)
        _last_rollout = create(:store_rollout, :completed, :last_but_not_hundred, type: "PlayStoreRollout", release_platform_run: last_run, store_submission: last_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:, scheduled_at: Time.current)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to eq(last_run)
      end

      it "only cares about the completed rollout that is the one before the current run" do
        release_platform = create(:release_platform, train:)

        previous_release = create(:release, :finished, train:)
        previous_run = create(:release_platform_run, :finished, release_platform:, release: previous_release, completed_at: Time.current - 2)
        previous_parent_release = create(:production_release, :finished, release_platform_run: previous_run)
        previous_store_submission = create(:play_store_submission, parent_release: previous_parent_release, release_platform_run: previous_run)
        _previous_rollout = create(:store_rollout, :completed, :last_but_not_hundred, type: "PlayStoreRollout", release_platform_run: previous_run, store_submission: previous_store_submission)

        last_release = create(:release, :stopped, train:)
        last_run = create(:release_platform_run, :stopped, release_platform:, release: last_release, scheduled_at: Time.current - 1)
        last_parent_release = create(:production_release, :finished, release_platform_run: last_run)
        last_store_submission = create(:play_store_submission, parent_release: last_parent_release, release_platform_run: last_run)
        _last_rollout = create(:store_rollout, :fully_released, type: "PlayStoreRollout", release_platform_run: last_run, store_submission: last_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:, scheduled_at: Time.current)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to be_nil
      end

      it "ignores completed rollouts that are already on 100% rollout" do
        _previous_rollout = create(:store_rollout, :completed, config: [1, 100], current_stage: 1,
          type: "PlayStoreRollout",
          release_platform_run: previous_run, store_submission: previous_store_submission)

        release = create(:release, :on_track, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        parent_release = create(:production_release, :finished, release_platform_run:)
        store_submission = create(:play_store_submission, parent_release:, release_platform_run:)
        _rollout = create(:store_rollout, :started, type: "PlayStoreRollout", release_platform_run:, store_submission:)

        expect(release_platform_run.previously_completed_rollout_run).to be_nil
      end
    end
  end
end
