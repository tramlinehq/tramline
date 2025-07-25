require "rails_helper"

PERFECT_SCORE_COMPONENTS = {
  hotfixes: {input: 0, range_value: 1, value: 0.3},
  rollout_fixes: {input: 0, range_value: 1, value: 0.2},
  rollout_duration: {input: 5, range_value: 1, value: 0.15},
  duration: {input: 6, range_value: 1, value: 0.05},
  stability_duration: {input: 1, range_value: 1, value: 0.15},
  stability_changes: {input: 5, range_value: 1, value: 0.15}
}

describe Release do
  let(:train) { create(:train) }
  let(:release) { create(:release, train: train) }
  let(:previous_release_one) { create(:release, train: train, status: "finished", created_at: 1.day.ago) }
  let(:approval_item) { create(:approval_item, release: previous_release_one) }
  let(:assignee) { create(:approval_assignee, approval_item:) }

  describe "after_commit callback#Releases::CopyPreviousApprovalsJob" do
    it "enqueues the CopyPreviousApprovalsJob after commit when copy_approvals_enabled? returns true" do
      allow(Releases::CopyPreviousApprovalsJob).to receive(:perform_async)
      release.train.update(copy_approvals: true)
      release.run_callbacks(:commit) { true }
      expect(Releases::CopyPreviousApprovalsJob).to have_received(:perform_async).with(release.id)
    end

    it "does not enqueue the CopyPreviousApprovalsJob if copys_approvals_enabled? returns false" do
      release.train.update(copy_approvals: false)
      allow(Releases::CopyPreviousApprovalsJob).to receive(:perform_async)

      release.run_callbacks(:commit) { true }
      expect(Releases::CopyPreviousApprovalsJob).not_to have_received(:perform_async)
    end
  end

  describe "delegates" do
    it "delegates app to train" do
      expect(release.app).to eq(train.app)
    end

    it "delegates vcs_provider to train" do
      expect(release.vcs_provider).to eq(train.vcs_provider)
    end

    it "delegates release_platforms to train" do
      expect(release.release_platforms).to eq(train.release_platforms)
    end

    it "delegates continuous_backmerge? to train" do
      expect(release.continuous_backmerge?).to eq(train.continuous_backmerge?)
    end

    it "delegates approvals_enabled? to train" do
      expect(release.approvals_enabled?).to eq(train.approvals_enabled?)
    end

    it "delegates copy_approvals? to train" do
      expect(release.copy_approvals?).to eq(train.copy_approvals?)
    end
  end

  describe "#copy_previous_approvals" do
    context "when a previous release exists" do
      let(:included_fields) { %w[author_id content] }
      let(:previous_release_two) { create(:release, train: train, status: "finished", created_at: 2.days.ago) }
      let(:approval_item_two) { create(:approval_item, release: previous_release_one) }

      before do
        previous_release_two.approval_items << approval_item_two
        previous_release_one.approval_items << approval_item

        allow(train).to receive(:previously_finished_release).and_return(previous_release_one)
        allow(release).to receive(:copy_approvals?).and_return(true)
      end

      it "copies approval items from the previous release" do
        release.copy_previous_approvals

        expect(release.approval_items.count).to eq(1)
        expect(release.approval_items.first.attributes.slice(*included_fields))
          .to eq(approval_item.attributes.slice(*included_fields))
      end
    end

    context "when no previous release is found" do
      let(:release) { build(:release) }

      before do
        allow(train).to receive(:previously_finished_release).and_return(nil)
        allow(release).to receive(:copy_approvals?).and_return(true)
      end

      it "handles copying approvals when no previous approvals exist" do
        release.copy_previous_approvals

        expect(release.approval_items).to be_empty
      end
    end
  end

  describe "#copy_approvals_enabled?" do
    context "when copy_approvals? is true and release is not nil" do
      it "returns true if copy_approvals? is true and release is not nil" do
        release.train.update(copy_approvals: true)
        expect(release.copy_approvals_enabled?).to be(true)
      end
    end

    context "when the train does not have copy_approvals enabled" do
      it "returns false" do
        release.train.update(copy_approvals: false)
        expect(release.copy_approvals_enabled?).to be(false)
      end
    end

    context "when release is hotfix" do
      it "returns false" do
        release.update(release_type: "hotfix")
        expect(release&.copy_approvals_enabled?).to be(false)
      end
    end
  end

  describe "#copy_approvals_allowed?" do
    context "when previously finished release is not available" do
      before do
        allow(train).to receive(:previously_finished_release).and_return(nil)
      end

      it "returns true regardless of other conditions" do
        expect(release.copy_approvals_allowed?).to be(false)
      end
    end

    context "when previously finished release is available" do
      before do
        allow(train).to receive(:previously_finished_release).and_return(instance_double(described_class))
      end

      it "returns false when it is a hotfix" do
        allow(release).to receive(:hotfix?).and_return(true)
        expect(release.copy_approvals_allowed?).to be(false)
      end

      it "returns true when it is not a hotfix" do
        allow(release).to receive(:hotfix?).and_return(false)
        expect(release.copy_approvals_allowed?).to be(true)
      end
    end
  end

  describe "#fetch_previous_finished_release" do
    let(:release) { create(:release, train: train, release_type: :release, created_at: Time.current) }

    context "when the previous release of type release exists" do
      let!(:release_a) { create(:release, train: train, release_type: :release, status: :finished, created_at: 3.days.ago) }
      let(:release_b) { create(:release, train: train, release_type: :hotfix, status: :finished, created_at: 2.days.ago) }

      it "fetches the most recent finished release of type release" do
        result = train.previously_finished_release
        expect(result).to eq(release_a)
      end
    end

    context "when the previous release of type hotfix exists" do
      let(:release_a) { create(:release, train: train, release_type: :hotfix, status: :finished, created_at: 3.days.ago) }
      let!(:release_b) { create(:release, train: train, release_type: :release, status: :finished, created_at: 2.days.ago) }

      it "fetches the most recent finished release of type release" do
        result = train.previously_finished_release
        expect(result).to eq(release_b)
      end
    end

    context "when the previous releases of type release exist but one is unfinished" do
      let!(:release_a) { create(:release, train: train, release_type: :release, status: :finished, created_at: 3.days.ago) }
      let(:release_b) { create(:release, train: train, release_type: :release, status: :stopped, created_at: 2.days.ago) }

      it "fetches the most recent finished release of type release" do
        result = train.previously_finished_release
        expect(result).to eq(release_a)
      end
    end
  end

  it "has a valid factory" do
    expect(create(:release)).to be_valid
  end

  it "generates unique slugs" do
    expect(create_list(:release, 5).map(&:slug).uniq.size).to eq(5)
  end

  describe ".create" do
    it "creates the release platform run for android platform" do
      app = create(:app, :android)
      train = create(:train, app:)
      run = create(:release, train:)

      expect(run.release_platform_runs.size).to eq(1)
    end

    it "creates the release platform run for each release platform" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)

      expect(run.release_platform_runs.size).to eq(2)
    end

    it "creates the release platform run hotfix platform when hotfix and hotfix platform is set" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      _older_release = create(:release, :finished, train:)
      run = create(:release, :hotfix, train:, hotfix_platform: "android")

      expect(run.release_platform_runs.size).to eq(1)
    end

    it "creates the release platform run for each release platform when hotfix and hotfix platform is not set" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      _older_release = create(:release, :finished, train:)
      run = create(:release, :hotfix, train:)

      expect(run.release_platform_runs.size).to eq(2)
    end
  end

  describe "#ready_to_be_finalized?" do
    it "is true when all release platform runs are finished" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)

      run.release_platform_runs.each do |run|
        run.update!(status: ReleasePlatformRun::STATES[:finished])
      end

      expect(run.ready_to_be_finalized?).to be(true)
    end

    it "is true when all release platform runs are finished ot stopped" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)
      run.release_platform_runs.first.update!(status: ReleasePlatformRun::STATES[:finished])
      run.release_platform_runs.last.update!(status: ReleasePlatformRun::STATES[:stopped])

      expect(run.ready_to_be_finalized?).to be(true)
    end

    it "is false when a release platform run is not finished" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)

      run.release_platform_runs.first.update!(status: ReleasePlatformRun::STATES[:finished])

      expect(run.ready_to_be_finalized?).to be(false)
    end
  end

  describe "#create_vcs_release!" do
    let(:train) { create(:train, :active) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release) { create(:release, train:) }
    let(:tag_exists_error) { Installations::Error.new("Should not create a tag", reason: :tag_reference_already_exists) }
    let(:release_exists_error) { Installations::Error.new("Should not create a release", reason: :tagged_release_already_exists) }

    before do
      create(:release_platform_run, :on_track, release:, release_platform:)
    end

    it "saves a new tag with the base name" do
      allow_any_instance_of(GithubIntegration).to receive(:create_release!)

      release.create_vcs_release!(anything, anything)
      expect(release.tag_name).to eq("v1.2.3")
    end

    it "saves base name + last commit sha" do
      raise_times(GithubIntegration, tag_exists_error, :create_release!, 1)
      commit = create(:commit, release:)

      release.create_vcs_release!(commit.commit_hash, anything)
      expect(release.tag_name).to eq("v1.2.3-#{commit.short_sha}")
    end

    it "saves base name + last commit sha + time" do
      raise_times(GithubIntegration, tag_exists_error, :create_release!, 2)

      freeze_time do
        now = Time.now.to_i
        commit = create(:commit, release:)

        release.create_vcs_release!(commit.commit_hash, anything)
        expect(release.tag_name).to eq("v1.2.3-#{commit.short_sha}-#{now}")
      end
    end

    context "when tag suffix" do
      let(:suffix) { "nightly" }
      let(:train) { create(:train, :active, tag_end_of_release_suffix: suffix) }

      it "saves a new tag with the base name + suffix" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)

        release.create_vcs_release!(anything, anything)
        expect(release.tag_name).to eq("v1.2.3-#{suffix}")
      end

      it "saves base name + suffix + last commit sha" do
        raise_times(GithubIntegration, release_exists_error, :create_release!, 1)
        commit = create(:commit, release:)

        release.create_vcs_release!(commit.commit_hash, anything)
        expect(release.tag_name).to eq("v1.2.3-#{suffix}-#{commit.short_sha}")
      end

      it "saves base name + suffix + last commit sha + time" do
        raise_times(GithubIntegration, release_exists_error, :create_release!, 2)

        freeze_time do
          now = Time.now.to_i
          commit = create(:commit, release:)

          release.create_vcs_release!(commit.commit_hash, anything)
          expect(release.tag_name).to eq("v1.2.3-#{suffix}-#{commit.short_sha}-#{now}")
        end
      end
    end

    context "when tag prefix" do
      let(:prefix) { "foo" }
      let(:train) { create(:train, :active, tag_end_of_release_prefix: prefix) }

      it "saves a new tag with the prefix + base name" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)

        release.create_vcs_release!(anything, anything)
        expect(release.tag_name).to eq("#{prefix}-v1.2.3")
      end

      it "saves prefix + base name + last commit sha" do
        raise_times(GithubIntegration, release_exists_error, :create_release!, 1)
        commit = create(:commit, release:)

        release.create_vcs_release!(commit.commit_hash, anything)
        expect(release.tag_name).to eq("#{prefix}-v1.2.3-#{commit.short_sha}")
      end

      it "saves base prefix + name + last commit sha + time" do
        raise_times(GithubIntegration, release_exists_error, :create_release!, 2)

        freeze_time do
          now = Time.now.to_i
          commit = create(:commit, release:)

          release.create_vcs_release!(commit.commit_hash, anything)
          expect(release.tag_name).to eq("#{prefix}-v1.2.3-#{commit.short_sha}-#{now}")
        end
      end
    end

    context "when tag prefix and tag suffix" do
      let(:prefix) { "foo" }
      let(:suffix) { "nightly" }
      let(:train) { create(:train, :active, tag_end_of_release_prefix: prefix, tag_end_of_release_suffix: suffix) }

      it "saves a new tag with the prefix + base name + suffix" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)

        release.create_vcs_release!(anything, anything)
        expect(release.tag_name).to eq("#{prefix}-v1.2.3-#{suffix}")
      end

      it "saves prefix + base name + suffix + last commit sha" do
        raise_times(GithubIntegration, release_exists_error, :create_release!, 1)
        commit = create(:commit, release:)

        release.create_vcs_release!(commit.commit_hash, anything)
        expect(release.tag_name).to eq("#{prefix}-v1.2.3-#{suffix}-#{commit.short_sha}")
      end

      it "saves base prefix + name + suffix + last commit sha + time" do
        raise_times(GithubIntegration, release_exists_error, :create_release!, 2)

        freeze_time do
          now = Time.now.to_i
          commit = create(:commit, release:)

          release.create_vcs_release!(commit.commit_hash, anything)
          expect(release.tag_name).to eq("#{prefix}-v1.2.3-#{suffix}-#{commit.short_sha}-#{now}")
        end
      end
    end
  end

  describe "#finish_after_partial_finish!" do
    let(:app) { create(:app, :cross_platform) }

    let(:train) { create(:train, app:) }
    let(:release) { create(:release, :partially_finished, train:) }

    it "does nothing unless release is partially finished", skip: "move to coordinators" do
      release = create(:release, :on_track, train:)
      release.finish_after_partial_finish!

      expect(release.reload.on_track?).to be(true)
    end

    it "stops the pending release platform run", skip: "move to coordinators" do
      first_prun = release.release_platform_runs.first
      second_prun = release.release_platform_runs.last
      first_prun.update!(status: ReleasePlatformRun::STATES[:finished])

      release.finish_after_partial_finish!
      expect(first_prun.reload.finished?).to be(true)
      expect(second_prun.reload.stopped?).to be(true)
    end

    it "starts the post release phase for the release", skip: "move to coordinators" do
      release.finish_after_partial_finish!

      expect(release.reload.post_release_started?).to be(true)
    end
  end

  describe "#retrigger_for_hotfix?" do
    it "is true when hotfix release and existing hotfix branch" do
      run = create(:release, :hotfix, :created, new_hotfix_branch: false)

      expect(run.hotfix_with_existing_branch?).to be(true)
    end

    it "is false when hotfix release and new hotfix branch" do
      run = create(:release, :hotfix, :created, new_hotfix_branch: true)

      expect(run.hotfix_with_existing_branch?).to be(false)
    end

    it "is false when not hotfix release" do
      run = create(:release, :created)

      expect(run.hotfix_with_existing_branch?).to be(false)
    end
  end

  describe "#fetch_commit_log" do
    def commit_attributes(commits)
      commits.map do |commit|
        attrs = commit.attributes.slice(
          "url", "message", "author_name", "commit_hash",
          "author_email", "author_login"
        )
        attrs["timestamp"] = commit.timestamp.strftime("%Y-%m-%dT%H:%M:%S.%3NZ")
        attrs["author_url"] = attrs["url"]
        attrs.with_indifferent_access
      end
    end

    let(:train) { create(:train) }
    let(:release) { create(:release, :on_track, train:) }
    let(:vcs_mock_provider) { instance_double(GithubIntegration) }
    let(:diff) {
      [{url: "https://sample.com",
        message: "commit message",
        timestamp: "2024-01-10T18:38:06.000Z",
        author_url: "https://sample.com",
        author_name: "Jon Doe",
        commit_hash: SecureRandom.uuid.split("-").join,
        author_email: "jon@doe.com",
        author_login: "jon-doe"}.with_indifferent_access]
    }

    before do
      allow_any_instance_of(described_class).to receive(:vcs_provider).and_return(vcs_mock_provider)
      allow(vcs_mock_provider).to receive(:commit_log).and_return(diff)
    end

    it "fetches the commits between last finished release and release branch" do
      finished_release = create(:release, :finished, train:, completed_at: 2.days.ago, tag_name: "foo")
      _older_finished_release = create(:release, :finished, train:, completed_at: 4.days.ago, tag_name: "bar")

      release.fetch_commit_log
      expect(vcs_mock_provider).to have_received(:commit_log).with(finished_release.tag_name, train.working_branch).once
      expect(commit_attributes(release.release_changelog.reload.commits)).to eq(diff)
      expect(release.release_changelog.reload.from_ref).to eq(finished_release.tag_name)
    end

    it "fetches the commits between ongoing release and release branch for upcoming release" do
      ongoing_release = create(:release, :on_track, train:, scheduled_at: 1.day.ago)
      commits = create_list(:commit, 5, release: ongoing_release, timestamp: Time.current - rand(1000))
      ongoing_head = commits.first

      release.fetch_commit_log
      expect(vcs_mock_provider).to have_received(:commit_log).with(ongoing_head.commit_hash, train.working_branch).once
      expect(commit_attributes(release.release_changelog.reload.commits)).to eq(diff)
      expect(release.release_changelog.reload.from_ref).to eq(ongoing_head.short_sha)
    end

    it "does not fetch commit log if no finished release exists for the train" do
      release.fetch_commit_log
      expect(vcs_mock_provider).not_to have_received(:commit_log)
      expect(release.release_changelog).to be_nil
    end

    context "when hotfix release" do
      it "fetches the commits between hotfixed from release and release branch" do
        finished_release = create(:release, :finished, train:, completed_at: 2.days.ago, tag_name: "foo")
        hotfix_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: finished_release)

        hotfix_release.fetch_commit_log
        expect(vcs_mock_provider).to have_received(:commit_log).with(finished_release.tag_name, release.release_branch).once
        expect(commit_attributes(hotfix_release.release_changelog.reload.commits)).to eq(diff)
        expect(hotfix_release.release_changelog.reload.from_ref).to eq(finished_release.tag_name)
      end

      it "does not fetch commit log when new hotfix branch" do
        finished_release = create(:release, :finished, train:, completed_at: 2.days.ago, tag_name: "foo")
        hotfix_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: finished_release, new_hotfix_branch: true)

        hotfix_release.fetch_commit_log
        expect(vcs_mock_provider).not_to have_received(:commit_log)
        expect(hotfix_release.release_changelog).to be_nil
      end
    end
  end

  describe "#stability_commits" do
    let(:release) { create(:release, :on_track) }

    it "returns the subsequent commits made on the release branch after release starts" do
      _initial_commit = create(:commit, release:)
      stability_commits = create_list(:commit, 4, release:)
      expect(release.stability_commits).to exist
      expect(release.stability_commits).to match_array(stability_commits)
      expect(release.all_commits.size).to eq(stability_commits.size + 1)
    end

    it "returns nothing if no fixes are made" do
      _initial_commit = create(:commit, release:)
      expect(release.all_commits).to exist
      expect(release.stability_commits).to be_none
    end
  end

  describe "#all_hotfixes" do
    it "returns all hotfixes for the release" do
      release = create(:release)
      hotfixes = create_list(:release, 3, :hotfix, hotfixed_from: release)

      expect(release.all_hotfixes).to match_array(hotfixes)
    end

    it "returns hotfixes of hotfixes" do
      release = create(:release)
      hotfix = create(:release, :hotfix, hotfixed_from: release)
      hotfix_hotfix = create(:release, :hotfix, hotfixed_from: hotfix)

      expect(release.all_hotfixes).to contain_exactly(hotfix, hotfix_hotfix)
    end
  end

  describe "#index_score" do
    it "returns nil for a hotfix" do
      hotfix = create(:release, :hotfix)

      expect(hotfix.index_score).to be_nil
    end

    it "returns nil for an unfinished release" do
      ongoing_release = create(:release, :on_track)
      stopped_release = create(:release, :stopped)

      expect(ongoing_release.index_score).to be_nil
      expect(stopped_release.index_score).to be_nil
    end

    [
      [PERFECT_SCORE_COMPONENTS, 1.0],
      [PERFECT_SCORE_COMPONENTS.merge(stability_changes: {input: 11, range_value: 0.5, value: 0.075}), 0.925],
      [PERFECT_SCORE_COMPONENTS.merge(
        duration: {input: 15, range_value: 0.5, value: 0.025},
        rollout_duration: {input: 9, range_value: 0.5, value: 0.075},
        stability_changes: {input: 11, range_value: 0.5, value: 0.075}
      ), 0.825],
      [PERFECT_SCORE_COMPONENTS.merge(
        hotfixes: {input: 1, range_value: 0, value: 0},
        duration: {input: 15, range_value: 0.5, value: 0.025},
        rollout_duration: {input: 9, range_value: 0.5, value: 0.075},
        stability_changes: {input: 11, range_value: 0.5, value: 0.075}
      ), 0.525],
      [PERFECT_SCORE_COMPONENTS.merge(
        hotfixes: {input: 1, range_value: 0, value: 0},
        rollout_fixes: {input: 2, range_value: 0, value: 0},
        duration: {input: 15, range_value: 0.5, value: 0.025},
        rollout_duration: {input: 9, range_value: 0.5, value: 0.075},
        stability_changes: {input: 11, range_value: 0.5, value: 0.075}
      ), 0.325]
    ].each do |components, final_score|
      it "returns the index score for a finished release" do
        train = create(:train, :with_no_platforms)
        release_platform = create(:release_platform, train:)

        travel_to(components[:duration][:input].days.ago)
        release = create(:release, :on_track, :with_no_platform_runs, train:)
        release_platform_run = create(:release_platform_run, release:, release_platform:)
        create_list(:commit, components[:stability_changes][:input] + 1, release:)
        travel_back

        travel_to(components[:rollout_duration][:input].days.ago)
        production_releases = create_list(:production_release, components[:rollout_fixes][:input], :stale, release_platform_run:, build: create(:build, release_platform_run:))
        production_releases.each do |production_release|
          store_submission = create(:play_store_submission, :prepared, parent_release: production_release)
          create(:store_rollout, :started, release_platform_run:, store_submission:)
        end
        production_release = create(:production_release, :active, release_platform_run:, build: create(:build, release_platform_run:))
        store_submission = create(:play_store_submission, :prepared, parent_release: production_release)
        store_rollout = create(:store_rollout, :started, release_platform_run:, store_submission:)
        travel_back

        store_rollout.update!(status: :completed)
        production_release.update!(status: :finished)
        release.update! completed_at: Time.current, status: :finished
        create_list(:release, components[:hotfixes][:input], :hotfix, hotfixed_from: release)

        expected_range_values = components.transform_values { |v| v[:range_value] }
        expected_values = components.transform_values { |v| v[:value] }

        score = release.index_score

        expect(score).to be_a(ReleaseIndex::Score)
        expect(score.components.map { |c| [c.release_index_component.name.to_sym, c.range_value] }.to_h).to eq(expected_range_values)
        expect(score.components.map { |c| [c.release_index_component.name.to_sym, c.value] }.to_h).to eq(expected_values)
        expect(score.value).to eq(final_score)
      end
    end
  end

  describe "#failure_anywhere?" do
    it "returns false if post release has failed" do
      release = create(:release, :post_release_failed)

      expect(release.failure_anywhere?).to be(false)
    end

    it "returns false if no failure" do
      release = create(:release, :on_track)

      expect(release.failure_anywhere?).to be(false)
    end

    context "when failure in a v2 release platform run" do
      let(:release) { create(:release, :on_track, :with_no_platform_runs) }
      let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }

      it "returns false if the latest production release has failed" do
        production_release = create(:production_release, :inflight, release_platform_run:)
        _submission = create(:play_store_submission, :failed, release_platform_run:, parent_release: production_release)

        expect(release.failure_anywhere?).to be(false)
      end

      it "returns false if a latest production release exists" do
        _production_release = create(:production_release, :inflight, release_platform_run:)

        expect(release.failure_anywhere?).to be(false)
      end

      it "returns true if the latest beta release has failed" do
        _beta_release = create(:beta_release, :failed, release_platform_run:)

        expect(release.failure_anywhere?).to be(true)
      end

      it "returns true if the latest internal release has failed" do
        _internal_release = create(:internal_release, :failed, release_platform_run:)

        expect(release.failure_anywhere?).to be(true)
      end

      it "returns false if the latest beta release has not failed, but latest internal release has failed" do
        _internal_release = create(:internal_release, :failed, release_platform_run:)
        beta_release = create(:beta_release, :finished, release_platform_run:)
        _workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: beta_release)
        _submission = create(:play_store_submission, :prepared, release_platform_run:, parent_release: beta_release)

        expect(release.failure_anywhere?).to be(false)
      end

      it "returns true if the latest internal release has failed after a beta release is a success" do
        _beta_release = create(:beta_release, :finished, release_platform_run:)
        _internal_release = create(:internal_release, :failed, release_platform_run:)

        expect(release.failure_anywhere?).to be(true)
      end

      it "returns true if either of the release platform run have failures" do
        app = create(:app, :cross_platform)
        train = create(:train, :with_no_platforms, app:)
        ios_release_platform = create(:release_platform, train:, platform: "ios")
        android_release_platform = create(:release_platform, train:, platform: "android")
        release = create(:release, :on_track, :with_no_platform_runs, train:)
        ios_release_platform_run = create(:release_platform_run, :on_track, release:, release_platform: ios_release_platform)
        android_release_platform_run = create(:release_platform_run, :on_track, release:, release_platform: android_release_platform)
        _beta_release = create(:beta_release, :failed, release_platform_run: android_release_platform_run)
        ios_beta_release = create(:beta_release, :finished, release_platform_run: ios_release_platform_run)
        _workflow_run = create(:workflow_run, :finished, release_platform_run:, triggering_release: ios_beta_release)
        _submission = create(:app_store_submission, :prepared, release_platform_run:, parent_release: ios_beta_release)

        expect(release.failure_anywhere?).to be(true)
      end
    end
  end

  describe "#override_approvals" do
    it "updates the approval_overridden_by field only if the release is active" do
      who = create(:user, :with_email_authentication, :as_developer)
      release = create(:release, :stopped, release_pilot: who)

      release.override_approvals(who)

      expect(release.approval_overridden_by).to be_nil
    end

    it "updates the approval_overridden_by only if the user is the release pilot" do
      who = create(:user, :with_email_authentication, :as_developer)
      release = create(:release, release_pilot: who)

      release.override_approvals(who)

      expect(release.approval_overridden_by).to eq(who)
    end

    it "does nothing if approvals are already overridden" do
      who = create(:user, :with_email_authentication, :as_developer)
      new_who = create(:user, :with_email_authentication, :as_developer)
      release = create(:release, release_pilot: who)

      release.override_approvals(who)
      release.override_approvals(new_who)

      expect(release.approval_overridden_by).to eq(who)
    end
  end

  describe "#blocked_for_production_release?" do
    let(:organization) { create(:organization, :with_owner_membership) }
    let(:app) { create(:app, :android, organization:) }

    it "is true when release is upcoming" do
      train = create(:train)
      _ongoing = create(:release, :on_track, train:)
      upcoming = create(:release, :on_track, train:)

      expect(upcoming.blocked_for_production_release?).to be(true)
    end

    it "is true when it is an hotfix release is simultaneously ongoing" do
      train = create(:train)
      finished_release = create(:release, :finished, train:, completed_at: 2.days.ago, tag_name: "foo")
      _hotfix_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: finished_release)
      ongoing_release = create(:release, :on_track, train:)

      expect(ongoing_release.blocked_for_production_release?).to be(true)
    end

    context "when approvals are enabled" do
      it "is true when approvals are blocking" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:)
        _approval_items = create_list(:approval_item, 5, release:, author: pilot)
        release.reload

        expect(release.blocked_for_production_release?).to be(true)
      end

      it "is false when approvals are non-blocking" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:)
        _approval_items = create_list(:approval_item, 5, :approved, release:, author: pilot)
        release.reload

        expect(release.blocked_for_production_release?).to be(false)
      end

      it "is true when approvals are not overridden" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:, approval_overridden_by: nil)
        _approval_items = create_list(:approval_item, 5, release:, author: pilot)

        expect(release.blocked_for_production_release?).to be(true)
      end

      it "is false when approvals are overridden (regardless of actual approvals)" do
        train = create(:train, approvals_enabled: true, app:)
        pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
        release = create(:release, release_pilot: pilot, train:, approval_overridden_by: pilot)

        create_list(:approval_item, 5, release:, author: pilot)
        create_list(:approval_item, 5, :approved, release:, author: pilot)

        expect(release.blocked_for_production_release?).to be(false)
      end
    end
  end

  describe "#last_applicable_commit" do
    let(:release) { create(:release, :on_track) }

    it "returns the last commit" do
      _older_commits = create_list(:commit, 3, release:)
      commit = create(:commit, release:)

      expect(release.last_applicable_commit).to eq(commit)
    end

    it "returns the last commit not in the active build queue" do
      build_queue = create(:build_queue, release:, is_active: true)
      _older_commits = create_list(:commit, 3, release:)
      commit_not_in_queue = create(:commit, release:)
      _commit_in_queue = create(:commit, release:, build_queue:)

      expect(release.last_applicable_commit).to eq(commit_not_in_queue)
    end

    it "returns the last commit when there is no active build queue" do
      build_queue = create(:build_queue, release:, is_active: false)
      _older_commits = create_list(:commit, 3, release:)
      _commit_not_in_queue = create(:commit, release:)
      commit_in_queue = create(:commit, release:, build_queue:)

      expect(release.last_applicable_commit).to eq(commit_in_queue)
    end
  end
end
