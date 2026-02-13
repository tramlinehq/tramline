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

    context "with iOS platform" do
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

    context "with Android platform" do
      let(:train) { create(:train, :with_no_platforms) }
      let(:release_platform) { create(:release_platform, platform: "android", train:) }
      let(:release) { create(:release, :with_no_platform_runs, train:) }
      let(:release_platform_run) { create(:release_platform_run, release_platform:, release:, release_version: "10.44.0") }

      context "with active production release" do
        it "filters by build number instead of version name" do
          # Build with version 10.44.0, build_number 124 (created first)
          older_build = create(:build, :rc, release_platform_run:, build_number: "124", generated_at: 3.days.ago)

          # Build with version 10.44.0, build_number 125 (rolled out)
          active_build = create(:build, :rc, release_platform_run:, build_number: "125", generated_at: 2.days.ago)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Bump version to 10.44.1 after rollout starts
          release_platform_run.update!(release_version: "10.44.1")

          # Build with version 10.44.1, build_number 126 (should be included - higher build number)
          newer_build = create(:build, :rc, release_platform_run:, build_number: "126")

          available = release_platform_run.available_rc_builds
          expect(available).not_to include(older_build) # build 124 < 125
          expect(available).to include(newer_build) # build 126 > 125
        end

        it "includes builds with same version but higher build number" do
          # Build with version 10.44.0, build_number 124 (rolled out)
          active_build = create(:build, :rc, release_platform_run:, build_number: "124", generated_at: 1.day.ago)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Build with version 10.44.0, build_number 125 (same version, higher build number, should be included)
          newer_build = create(:build, :rc, release_platform_run:, build_number: "125")

          available = release_platform_run.available_rc_builds
          expect(available).to include(newer_build)
        end

        it "excludes builds with lower build number" do
          # Build with version 10.44.0, build_number 124 (created first)
          older_build_1 = create(:build, :rc, release_platform_run:, build_number: "124", generated_at: 3.days.ago)

          # Build with version 10.44.0, build_number 125 (created second)
          older_build_2 = create(:build, :rc, release_platform_run:, build_number: "125", generated_at: 2.days.ago)

          # Build with version 10.44.0, build_number 126 (rolled out)
          active_build = create(:build, :rc, release_platform_run:, build_number: "126", generated_at: 1.day.ago)
          create(:production_release, :active, release_platform_run:, build: active_build)

          # Bump version to 10.44.1
          release_platform_run.update!(release_version: "10.44.1")

          # Build with version 10.44.1, build_number 127 (higher build number, should be included)
          newer_build = create(:build, :rc, release_platform_run:, build_number: "127")

          available = release_platform_run.available_rc_builds
          expect(available).not_to include(older_build_1) # build 124 < 126
          expect(available).not_to include(older_build_2) # build 125 < 126
          expect(available).to include(newer_build) # build 127 > 126
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

  describe "state transitions" do
    let(:release) { create(:release) }
    let(:release_platform_run) { create(:release_platform_run, :created, release:) }

    describe "#start!" do
      it "transitions from created to on_track" do
        expect(release_platform_run.status).to eq("created")
        release_platform_run.start!
        expect(release_platform_run.reload.status).to eq("on_track")
      end

      it "transitions from concluded to on_track (reactivation)" do
        release_platform_run.update!(status: ReleasePlatformRun::STATES[:on_track])
        release_platform_run.conclude!
        expect(release_platform_run.reload.status).to eq("concluded")

        release_platform_run.start!
        expect(release_platform_run.reload.status).to eq("on_track")
      end

      it "does not transition from finished" do
        release_platform_run.update!(status: ReleasePlatformRun::STATES[:finished])
        release_platform_run.start!
        expect(release_platform_run.reload.status).to eq("finished")
      end

      it "does not transition from stopped" do
        release_platform_run.update!(status: ReleasePlatformRun::STATES[:stopped])
        release_platform_run.start!
        expect(release_platform_run.reload.status).to eq("stopped")
      end
    end

    describe "#conclude!" do
      it "transitions from on_track to concluded" do
        release_platform_run.start!
        expect(release_platform_run.reload.status).to eq("on_track")

        release_platform_run.conclude!
        expect(release_platform_run.reload.status).to eq("concluded")
      end

      it "does not set completed_at timestamp" do
        release_platform_run.start!
        release_platform_run.conclude!
        expect(release_platform_run.reload.completed_at).to be_nil
      end

      it "does not transition from created" do
        expect(release_platform_run.status).to eq("created")
        release_platform_run.conclude!
        expect(release_platform_run.reload.status).to eq("created")
      end

      it "does not transition from finished" do
        release_platform_run.update!(status: ReleasePlatformRun::STATES[:finished])
        release_platform_run.conclude!
        expect(release_platform_run.reload.status).to eq("finished")
      end
    end

    describe "#finish!" do
      it "transitions from concluded to finished" do
        release_platform_run.start!
        release_platform_run.conclude!
        expect(release_platform_run.reload.status).to eq("concluded")

        release_platform_run.finish!
        expect(release_platform_run.reload.status).to eq("finished")
      end

      it "sets completed_at timestamp" do
        release_platform_run.start!
        release_platform_run.conclude!
        release_platform_run.finish!

        expect(release_platform_run.reload.completed_at).to be_present
        expect(release_platform_run.completed_at).to be_within(1.second).of(Time.current)
      end

      it "does not transition from on_track" do
        release_platform_run.start!
        expect(release_platform_run.reload.status).to eq("on_track")

        release_platform_run.finish!
        expect(release_platform_run.reload.status).to eq("on_track")
      end

      it "does not transition from created" do
        expect(release_platform_run.status).to eq("created")
        release_platform_run.finish!
        expect(release_platform_run.reload.status).to eq("created")
      end
    end

    describe "#stop!" do
      it "transitions from created to stopped" do
        expect(release_platform_run.status).to eq("created")
        release_platform_run.stop!
        expect(release_platform_run.reload.status).to eq("stopped")
      end

      it "transitions from on_track to stopped" do
        release_platform_run.start!
        release_platform_run.stop!
        expect(release_platform_run.reload.status).to eq("stopped")
      end

      it "transitions from concluded to stopped" do
        release_platform_run.start!
        release_platform_run.conclude!
        release_platform_run.stop!
        expect(release_platform_run.reload.status).to eq("stopped")
      end

      it "sets stopped_at timestamp" do
        release_platform_run.stop!
        expect(release_platform_run.reload.stopped_at).to be_present
      end

      it "does not transition from finished" do
        release_platform_run.update!(status: ReleasePlatformRun::STATES[:finished])
        release_platform_run.stop!
        expect(release_platform_run.reload.status).to eq("finished")
      end
    end
  end

  describe "#active?" do
    let(:release) { create(:release) }
    let(:release_platform_run) { create(:release_platform_run, :created, release:) }

    it "is true when created" do
      expect(release_platform_run.status).to eq("created")
      expect(release_platform_run.active?).to be(true)
    end

    it "is true when on_track" do
      release_platform_run.start!
      expect(release_platform_run.active?).to be(true)
    end

    it "is false when concluded" do
      release_platform_run.start!
      release_platform_run.conclude!
      expect(release_platform_run.active?).to be(false)
    end

    it "is false when finished" do
      release_platform_run.update!(status: ReleasePlatformRun::STATES[:finished])
      expect(release_platform_run.active?).to be(false)
    end

    it "is false when stopped" do
      release_platform_run.stop!
      expect(release_platform_run.active?).to be(false)
    end
  end

  describe "#blocked_for_production_release?" do
    let(:organization) { create(:organization, :with_owner_membership) }
    let(:app) { create(:app, :android, organization:) }

    it "is true when release is upcoming and an ongoing release has an active production release" do
      train = create(:train)
      release_platform = create(:release_platform)
      ongoing = create(:release, :with_no_platform_runs, :on_track, train:)
      ongoing_rpr = create(:release_platform_run, release: ongoing, release_platform:)
      _ongoing_production_release = create(:production_release,
        :active,
        release_platform_run: ongoing_rpr,
        build: create(:build, release_platform_run: ongoing_rpr))
      upcoming = create(:release, :with_no_platform_runs, :on_track, train:)

      upcoming_platform_run = create(:release_platform_run, release: upcoming, release_platform:)

      expect(upcoming_platform_run.blocked_for_production_release?).to be(true)
    end

    it "is false when release is upcoming and train allows upcoming release submissions" do
      train = create(:train, allow_upcoming_release_submissions: true)
      release_platform = create(:release_platform)
      ongoing = create(:release, :with_no_platform_runs, :on_track, train:)
      ongoing_rpr = create(:release_platform_run, release: ongoing, release_platform:)
      _ongoing_production_release = create(:production_release,
        :active,
        release_platform_run: ongoing_rpr,
        build: create(:build, release_platform_run: ongoing_rpr))
      upcoming = create(:release, :with_no_platform_runs, :on_track, train:)

      upcoming_platform_run = create(:release_platform_run, release: upcoming, release_platform:)

      expect(upcoming_platform_run.blocked_for_production_release?).to be(false)
    end

    it "is true when it is an hotfix release is simultaneously ongoing" do
      train = create(:train)
      finished_release = create(:release, :finished, train:, completed_at: 2.days.ago, tag_name: "foo")
      _hotfix_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: finished_release)
      ongoing_release = create(:release, :on_track, train:)
      platform_run = ongoing_release.release_platform_runs.first

      expect(platform_run.blocked_for_production_release?).to be(true)
    end

    context "when approvals are enabled" do
      it "is true when approvals are blocking" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:)
        _approval_items = create_list(:approval_item, 5, release:, author: pilot)
        release.reload
        platform_run = release.release_platform_runs.first

        expect(platform_run.blocked_for_production_release?).to be(true)
      end

      it "is false when approvals are non-blocking" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:)
        _approval_items = create_list(:approval_item, 5, :approved, release:, author: pilot)
        release.reload
        platform_run = release.release_platform_runs.first

        expect(platform_run.blocked_for_production_release?).to be(false)
      end

      it "is true when approvals are not overridden" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:, approval_overridden_by: nil)
        _approval_items = create_list(:approval_item, 5, release:, author: pilot)
        platform_run = release.release_platform_runs.first

        expect(platform_run.blocked_for_production_release?).to be(true)
      end

      it "is false when approvals are overridden (regardless of actual approvals)" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:, approval_overridden_by: pilot)

        create_list(:approval_item, 5, release:, author: pilot)
        create_list(:approval_item, 5, :approved, release:, author: pilot)
        platform_run = release.release_platform_runs.first

        expect(platform_run.blocked_for_production_release?).to be(false)
      end
    end

    context "when upcoming release with cross-platform train (override)" do
      let(:train) { create(:train, :with_no_platforms) }
      let(:android_platform) { create(:release_platform, train:, platform: "android") }
      let(:ios_platform) { create(:release_platform, train:, platform: "ios") }

      it "blocked_for_production_release_override? is true when upcoming, config enabled, and blocked by ongoing platform" do
        train.update!(allow_upcoming_release_submissions: true)

        ongoing_release = create(:release, :with_no_platform_runs, train:)
        _ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release_override?).to be(true)
      end

      it "blocked_for_production_release_override? is false when config is disabled" do
        train.update!(allow_upcoming_release_submissions: false)

        ongoing_release = create(:release, :with_no_platform_runs, train:)
        _ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release_override?).to be(false)
      end

      it "blocked_for_production_release_override? is false when release is not upcoming (ongoing)" do
        train.update!(allow_upcoming_release_submissions: true)

        ongoing_release = create(:release, :with_no_platform_runs, :on_track, train:)
        ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        expect(ongoing_android_run.blocked_for_production_release_override?).to be(false)
      end

      it "blocked_for_production_release_override? is false when not blocked by ongoing platform" do
        train.update!(allow_upcoming_release_submissions: true)

        ongoing_release = create(:release, :with_no_platform_runs, train:)
        ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        # conclude the ongoing platform run so it's no longer blocking
        ongoing_android_run.conclude!

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release_override?).to be(false)
      end
    end

    context "when upcoming release with cross-platform train" do
      let(:train) { create(:train, :with_no_platforms) }
      let(:android_platform) { create(:release_platform, train:, platform: "android") }
      let(:ios_platform) { create(:release_platform, train:, platform: "ios") }

      it "is false when corresponding platform run in ongoing release is concluded" do
        ongoing_release = create(:release, :with_no_platform_runs, train:)
        ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        ongoing_android_run.conclude!

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release?).to be(false)
      end

      it "is false when corresponding platform run in ongoing release is finished" do
        ongoing_release = create(:release, :with_no_platform_runs, train:)
        ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        ongoing_android_run.conclude!
        ongoing_android_run.finish!

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release?).to be(false)
      end

      it "is true when corresponding platform run in ongoing release is on_track (regardless of production release)" do
        ongoing_release = create(:release, :with_no_platform_runs, train:)
        ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        build = create(:build, release_platform_run: ongoing_android_run)
        create(:production_release, :active, release_platform_run: ongoing_android_run, build:)

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release?).to be(true)
      end

      it "is true when corresponding platform run in ongoing release is on_track" do
        ongoing_release = create(:release, :with_no_platform_runs, train:)
        _ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        _ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        _upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_android_run.blocked_for_production_release?).to be(true)
      end

      it "allows iOS to proceed independently while Android is blocked" do
        ongoing_release = create(:release, :with_no_platform_runs, train:)
        _ongoing_android_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: android_platform)
        ongoing_ios_run = create(:release_platform_run, :on_track, release: ongoing_release, release_platform: ios_platform)

        ongoing_ios_run.conclude!

        upcoming_release = create(:release, :with_no_platform_runs, train:)
        upcoming_android_run = create(:release_platform_run, release: upcoming_release, release_platform: android_platform)
        upcoming_ios_run = create(:release_platform_run, release: upcoming_release, release_platform: ios_platform)

        expect(upcoming_ios_run.blocked_for_production_release?).to be(false)
        expect(upcoming_android_run.blocked_for_production_release?).to be(true)
      end
    end
  end

  describe "#committable?" do
    let(:release) { create(:release) }
    let(:release_platform_run) { create(:release_platform_run, :created, release:) }

    it "is true when on_track" do
      release_platform_run.start!
      expect(release_platform_run.committable?).to be(true)
    end

    it "is true when concluded (allows reactivation)" do
      release_platform_run.start!
      release_platform_run.conclude!
      expect(release_platform_run.committable?).to be(true)
    end

    it "is false when created" do
      expect(release_platform_run.status).to eq("created")
      expect(release_platform_run.committable?).to be(false)
    end

    it "is false when finished" do
      release_platform_run.update!(status: ReleasePlatformRun::STATES[:finished])
      expect(release_platform_run.committable?).to be(false)
    end

    it "is false when stopped" do
      release_platform_run.stop!
      expect(release_platform_run.committable?).to be(false)
    end
  end
end
