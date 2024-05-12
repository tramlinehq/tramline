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
  it "has a valid factory" do
    expect(create(:release)).to be_valid
  end

  describe "#set_version" do
    {
      "1.2.3" => {major: "2.0.0", minor: "1.3.0"},
      "1.2" => {major: "2.0", minor: "1.3"}
    }.each do |ver, expect|
      it "minor bump: sets the original_release_version to next version of the train" do
        train = create(:train, version_seeded_with: ver)
        run = build(:release, original_release_version: nil, train:)

        expect(run.original_release_version).to be_nil
        run.save!
        expect(run.original_release_version).to eq(expect[:minor])
      end

      it "major bump: sets the original_release_version to next version of the train" do
        train = create(:train, version_seeded_with: ver)
        run = build(:release, original_release_version: nil, train:)
        run.has_major_bump = true

        expect(run.original_release_version).to be_nil
        run.save!
        expect(run.original_release_version).to eq(expect[:major])
      end
    end

    context "when hotfix release" do
      it "patch bump: sets the original_release_version to the next version of a the previous good run" do
        train = create(:train, :with_almost_trunk, :with_no_platforms, :active, version_seeded_with: "1.2.3")
        release = create(:release, :finished, :with_no_platform_runs, train:)
        release_platform = create(:release_platform, train:)
        _finished_release_run = create(:release_platform_run, release:, release_platform:, release_version: "1.2.3")

        hotfix_run = build(:release, :hotfix, :with_no_platform_runs, original_release_version: nil, train:)

        expect(hotfix_run.original_release_version).to be_nil
        hotfix_run.save!
        expect(hotfix_run.original_release_version).to eq("1.2.4")
      end

      it "minor bump: sets the original_release_version to the next version of a the previous good run" do
        train = create(:train, :with_almost_trunk, :with_no_platforms, :active, version_seeded_with: "1.2")
        release = create(:release, :finished, :with_no_platform_runs, train:)
        release_platform = create(:release_platform, train:)
        _finished_release_run = create(:release_platform_run, release:, release_platform:, release_version: "1.2")

        hotfix_run = build(:release, :hotfix, :with_no_platform_runs, original_release_version: nil, train:)

        expect(hotfix_run.original_release_version).to be_nil
        hotfix_run.save!
        expect(hotfix_run.original_release_version).to eq("1.3")
      end
    end

    context "when ongoing release" do
      {
        "1.2.3" => {major: "2.0.0", minor: "1.4.0"},
        "1.2" => {major: "2.0", minor: "1.4"}
      }.each do |ver, expect|
        it "minor bump: sets the original_release_version to next version of the ongoing release" do
          train = create(:train, version_seeded_with: ver)
          _ongoing_release = create(:release, :on_track, train:)
          run = build(:release, original_release_version: nil, train:)

          expect(run.original_release_version).to be_nil
          run.save!
          expect(run.original_release_version).to eq(expect[:minor])
        end

        it "major bump: sets the original_release_version to next version of the ongoing release" do
          train = create(:train, version_seeded_with: ver)
          _ongoing_release = create(:release, :on_track, train:)
          run = build(:release, original_release_version: nil, train:)
          run.has_major_bump = true

          expect(run.original_release_version).to be_nil
          run.save!
          expect(run.original_release_version).to eq(expect[:major])
        end
      end
    end

    context "when ongoing hotfix release" do
      {
        "1.2.3" => {major: "2.0.0", minor: "1.4.0"},
        "1.2" => {major: "2.0", minor: "1.5"}
      }.each do |ver, expect|
        it "minor bump: sets the original_release_version to next version of the hotfix release" do
          train = create(:train, version_seeded_with: ver)
          old_release = create(:release, :finished, train:)
          _ongoing_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: old_release)
          run = build(:release, original_release_version: nil, train:)

          expect(run.original_release_version).to be_nil
          run.save!
          expect(run.original_release_version).to eq(expect[:minor])
        end

        it "major bump: sets the original_release_version to next version of the hotfix release" do
          train = create(:train, version_seeded_with: ver)
          old_release = create(:release, :finished, train:)
          _ongoing_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: old_release)
          run = build(:release, original_release_version: nil, train:)
          run.has_major_bump = true

          expect(run.original_release_version).to be_nil
          run.save!
          expect(run.original_release_version).to eq(expect[:major])
        end
      end
    end
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

  describe "#create_release!" do
    let(:train) { create(:train, :active) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:step) { create(:step, release_platform:) }
    let(:release) { create(:release, train:) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release:, release_platform:) }

    it "saves a new tag with the base name" do
      allow_any_instance_of(GithubIntegration).to receive(:create_release!)
      commit = create(:commit, :without_trigger, release:)
      create(:step_run, release_platform_run:, commit:)

      release.create_release!
      expect(release.tag_name).to eq("v1.2.3")
    end

    it "saves base name + last commit sha" do
      raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 1)
      commit = create(:commit, :without_trigger, release:)
      create(:step_run, release_platform_run:, commit:)

      release.create_release!
      expect(release.tag_name).to eq("v1.2.3-#{commit.short_sha}")
    end

    it "saves base name + last commit sha + time" do
      raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 2)

      freeze_time do
        now = Time.now.to_i
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect(release.tag_name).to eq("v1.2.3-#{commit.short_sha}-#{now}")
      end
    end

    context "when tag suffix" do
      let(:suffix) { "nightly" }
      let(:train) { create(:train, :active, tag_suffix: suffix) }

      it "saves a new tag with the base name + suffix" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect(release.tag_name).to eq("v1.2.3-#{suffix}")
      end

      it "saves base name + suffix + last commit sha" do
        raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 1)
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect(release.tag_name).to eq("v1.2.3-#{suffix}-#{commit.short_sha}")
      end

      it "saves base name + suffix + last commit sha + time" do
        raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 2)

        freeze_time do
          now = Time.now.to_i
          commit = create(:commit, :without_trigger, release:)
          create(:step_run, release_platform_run:, commit:)

          release.create_release!
          expect(release.tag_name).to eq("v1.2.3-#{suffix}-#{commit.short_sha}-#{now}")
        end
      end
    end

    context "when release tag disabled" do
      let(:train) { create(:train, :active, tag_releases: false) }

      it "does not create tag" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect_any_instance_of(GithubIntegration).not_to receive(:create_release!)
        expect(release.tag_name).to be_nil
      end
    end
  end

  describe "#stop!" do
    it "updates the train version if partially finished" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :partially_finished, train:)

      run.stop!
      train.reload

      expect(train.version_current).to eq("9.60.0")
    end

    it "does not update the train version if properly stopped" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :post_release_started, train:)

      run.stop!
      train.reload

      expect(train.version_current).to eq("9.59.3")
    end
  end

  describe "#finish!" do
    it "updates the train version" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :post_release_started, train:)

      run.finish!
      train.reload

      expect(train.version_current).to eq("9.60.0")
    end
  end

  describe "#finish_after_partial_finish!" do
    let(:app) { create(:app, :cross_platform) }

    let(:train) { create(:train, app:) }
    let(:release) { create(:release, :partially_finished, train:) }

    it "does nothing unless release is partially finished" do
      release = create(:release, :on_track, train:)
      release.finish_after_partial_finish!

      expect(release.reload.on_track?).to be(true)
    end

    it "stops the pending release platform run" do
      first_prun = release.release_platform_runs.first
      second_prun = release.release_platform_runs.last
      first_prun.update!(status: ReleasePlatformRun::STATES[:finished])

      release.finish_after_partial_finish!
      expect(first_prun.reload.finished?).to be(true)
      expect(second_prun.reload.stopped?).to be(true)
    end

    it "starts the post release phase for the release" do
      release.finish_after_partial_finish!

      expect(release.reload.post_release_started?).to be(true)
    end
  end

  describe "#retrigger_for_hotfix?" do
    it "is true when hotfix release and existing hotfix branch" do
      run = create(:release, :hotfix, :created, new_hotfix_branch: false)

      expect(run.retrigger_for_hotfix?).to be(true)
    end

    it "is false when hotfix release and new hotfix branch" do
      run = create(:release, :hotfix, :created, new_hotfix_branch: true)

      expect(run.retrigger_for_hotfix?).to be(false)
    end

    it "is false when not hotfix release" do
      run = create(:release, :created)

      expect(run.retrigger_for_hotfix?).to be(false)
    end
  end

  describe "#fetch_commit_log" do
    let(:train) { create(:train) }
    let(:release) { create(:release, :on_track, train:) }
    let(:vcs_mock_provider) { instance_double(GithubIntegration) }
    let(:diff) {
      [{url: "https://sample.com",
        message: "commit message",
        timestamp: "2024-01-10T18:38:06.000Z",
        author_url: "https://github.com/jondoe",
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
      expect(release.release_changelog.reload.commits.map(&:with_indifferent_access)).to eq(diff)
      expect(release.release_changelog.reload.from_ref).to eq(finished_release.tag_name)
    end

    it "fetches the commits between ongoing release and release branch for upcoming release" do
      ongoing_release = create(:release, :on_track, train:, scheduled_at: 1.day.ago)
      commits = create_list(:commit, 5, :without_trigger, release: ongoing_release)
      ongoing_head = commits.first

      release.fetch_commit_log
      expect(vcs_mock_provider).to have_received(:commit_log).with(ongoing_head.commit_hash, train.working_branch).once
      expect(release.release_changelog.reload.commits.map(&:with_indifferent_access)).to eq(diff)
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
        expect(hotfix_release.release_changelog.reload.commits.map(&:with_indifferent_access)).to eq(diff)
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
    let(:factory_tree) { create_deployment_run_tree(:android, release_traits: [:on_track]) }
    let(:release) { factory_tree[:release] }

    it "returns the subsequent commits made on the release branch after release starts" do
      stability_commits = create_list(:commit, 4, release:)
      expect(release.stability_commits).to exist
      expect(release.stability_commits).to eq(stability_commits)
      expect(release.all_commits.size).to eq(stability_commits.size + 1)
    end

    it "returns nothing if no fixes are made" do
      expect(release.all_commits).to exist
      expect(release.stability_commits).to be_none
    end
  end

  describe "#all_hotfixes" do
    it "returns all hotfixes for the release" do
      release = create(:release)
      hotfixes = create_list(:release, 3, :hotfix, hotfixed_from: release)

      expect(release.all_hotfixes).to contain_exactly(*hotfixes)
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
        hotfixes: {input: 1, range_value: 0.5, value: 0.15},
        duration: {input: 15, range_value: 0.5, value: 0.025},
        rollout_duration: {input: 9, range_value: 0.5, value: 0.075},
        stability_changes: {input: 11, range_value: 0.5, value: 0.075}
      ), 0.675],
      [PERFECT_SCORE_COMPONENTS.merge(
        hotfixes: {input: 1, range_value: 0, value: 0},
        rollout_fixes: {input: 2, range_value: 0, value: 0},
        duration: {input: 15, range_value: 0.5, value: 0.025},
        rollout_duration: {input: 9, range_value: 0.5, value: 0.075},
        stability_changes: {input: 11, range_value: 0.5, value: 0.075}
      ), 0.325]
    ].each do |components, final_score|
      it "returns the index score for a finished release" do
        create_deployment_tree(:android, :with_staged_rollout, step_traits: [:release]) => { step:, deployment:, train: }

        travel_to(components[:duration][:input].days.ago)
        release = create(:release, :on_track, :with_no_platform_runs, train:)
        release_platform_run = create(:release_platform_run, release:)
        create_list(:commit, components[:stability_changes][:input] + 1, release:)
        travel_back

        travel_to((components[:rollout_duration][:input] - 2).days.ago)
        submitted_step_run = create(:step_run, :deployment_started, release_platform_run:, step:)
        create(:deployment_run, :rollout_started, step_run: submitted_step_run, deployment:)
        travel_back

        travel_to(components[:rollout_duration][:input].days.ago)
        step_runs = create_list(:step_run, components[:rollout_fixes][:input], :deployment_started, release_platform_run:, step:)
        step_runs.each do |step_run|
          create(:deployment_run, :rollout_started, step_run:, deployment:)
        end
        step_run = create(:step_run, :deployment_started, release_platform_run:)
        deployment_run = create(:deployment_run, :rollout_started, step_run:, deployment:)
        travel_back

        deployment_run.complete!
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
end
