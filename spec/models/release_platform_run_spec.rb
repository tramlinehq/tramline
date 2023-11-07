require "rails_helper"

describe ReleasePlatformRun do
  it "has a valid factory" do
    expect(create(:release_platform_run)).to be_valid
  end

  describe "#metadata_editable" do
    let(:release_platform) { create(:release_platform) }
    let(:review_step) { create(:step, :review, :with_deployment, release_platform:) }
    let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
    let(:regular_deployment) { create(:deployment, :with_google_play_store, step: release_step) }
    let(:production_deployment) { create(:deployment, :with_google_play_store, :with_staged_rollout, step: release_step) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release_platform:) }

    it "is true when release is on track and does not have deployment runs" do
      expect(release_platform_run.metadata_editable?).to be(true)
    end

    it "is true when release is on track and does not have a release step run" do
      _review_step_run = create(:step_run, step: review_step, release_platform_run:)
      expect(release_platform_run.metadata_editable?).to be(true)
    end

    it "is true when release is on track, has a release step run but no production deployment run" do
      release_step_run = create(:step_run, step: release_step, release_platform_run:)
      create(:deployment_run, deployment: regular_deployment, step_run: release_step_run)
      expect(release_platform_run.metadata_editable?).to be(true)
    end

    it "is false when release is on track, has a release step run and production deployment run" do
      release_step_run = create(:step_run, step: release_step, release_platform_run:)
      create(:deployment_run, deployment: production_deployment, step_run: release_step_run)
      expect(release_platform_run.metadata_editable?).to be(false)
    end

    it "is false release train is finished" do
      release_platform_run.update(status: "finished")
      expect(release_platform_run.metadata_editable?).to be(false)
    end
  end

  describe "#next_step" do
    subject(:run) { create(:release_platform_run) }

    let(:steps) { create_list(:step, 5, :with_deployment, release_platform: run.release_platform) }

    it "returns next step" do
      expect(run.next_step).to be_nil
    end
  end

  describe "#manually_startable_step?" do
    let(:release_platform) { create(:release_platform) }
    let(:steps) { create_list(:step, 2, :with_deployment, release_platform:) }

    it "first step can be started if there are no step runs" do
      release_platform_run = create(:release_platform_run, release_platform:)

      expect(release_platform_run.manually_startable_step?(steps.first)).to be(true)
      expect(release_platform_run.manually_startable_step?(steps.second)).to be(false)
    end

    it "next step can be started after finishing previous step" do
      release_platform_run = create(:release_platform_run, release_platform: release_platform)
      create(:step_run, step: steps.first, status: "success", release_platform_run: release_platform_run)

      expect(release_platform_run.manually_startable_step?(steps.first)).to be(false)
      expect(release_platform_run.manually_startable_step?(steps.second)).to be(true)
    end
  end

  describe "#overall_movement_status" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release) { create(:release, train:) }

    it "returns the status of every step of the train" do
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      commit = create(:commit, release:)
      steps = create_list(:step, 4, :with_deployment, release_platform:)
      _step_run_1 = create(:step_run, commit:, step: steps.first, status: "success", release_platform_run:)
      _step_run_2 = create(:step_run, commit:, step: steps.second, status: "ci_workflow_failed", release_platform_run:)
      _step_run_3 = create(:step_run, commit:, step: steps.third, status: "on_track", release_platform_run:)

      expectation = {
        steps.first => {in_progress: false, done: true, failed: false},
        steps.second => {in_progress: false, done: false, failed: true},
        steps.third => {in_progress: true, done: false, failed: false},
        steps.fourth => {not_started: true}
      }

      expect(release_platform_run.overall_movement_status).to eq(expectation)
    end

    it "always accounts for the last step run of a particular step" do
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      commit_1 = create(:commit, release:)
      commit_2 = create(:commit, release:)
      steps = create_list(:step, 2, :with_deployment, release_platform:)
      _step_run_1 = create(:step_run, commit: commit_1, step: steps.first, status: "success", release_platform_run:)
      _step_run_1 = create(:step_run, commit: commit_2, step: steps.first, status: "ci_workflow_unavailable", release_platform_run:)
      _step_run_2 = create(:step_run, commit: commit_1, step: steps.second, status: "ci_workflow_failed", release_platform_run:)
      _step_run_2 = create(:step_run, commit: commit_2, step: steps.second, status: "success", release_platform_run:)

      expectation = {
        steps.first => {in_progress: false, done: false, failed: true},
        steps.second => {in_progress: false, done: true, failed: false}
      }

      expect(release_platform_run.overall_movement_status).to eq(expectation)
    end
  end

  describe "finalizable?" do
    let(:release_platform) { create(:release_platform) }
    let(:review_step) { create(:step, :review, :with_deployment, release_platform:) }
    let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }

    it "is finalizable when release step for the last commit have succeeded" do
      commit_1 = create(:commit, :without_trigger, release: release_platform_run.release)
      _commit_1_fail = create(:step_run, :ci_workflow_failed, commit: commit_1, step: review_step, release_platform_run:)
      _commit_1_pass = create(:step_run, :success, commit: commit_1, step: release_step, release_platform_run:)

      commit_2 = create(:commit, :without_trigger, release: release_platform_run.release)
      _commit_2_pass = create(:step_run, :deployment_failed, commit: commit_2, step: review_step, release_platform_run:)
      _commit_2_pass = create(:step_run, :success, commit: commit_2, step: release_step, release_platform_run:)

      expect(release_platform_run.finalizable?).to be(true)
    end

    it "is not finalizable when release step for the last commit have not succeeded" do
      commit_1 = create(:commit, :without_trigger, release: release_platform_run.release)
      _commit_1_pass = create(:step_run, :success, commit: commit_1, step: review_step, release_platform_run:)
      _commit_1_fail = create(:step_run, :ci_workflow_failed, commit: commit_1, step: release_step, release_platform_run:)

      commit_2 = create(:commit, :without_trigger, release: release_platform_run.release)
      _commit_2_fail = create(:step_run, :success, commit: commit_2, step: review_step, release_platform_run:)
      _commit_2_pass = create(:step_run, :deployment_started, commit: commit_2, step: release_step, release_platform_run:)

      expect(release_platform_run.finalizable?).to be(false)
    end
  end

  describe "#release_fix?" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:review_step) { create(:step, :review, :with_deployment, release_platform:) }
    let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
    let(:regular_deployment) { create(:deployment, :with_google_play_store, step: release_step) }
    let(:production_deployment) { create(:deployment, :with_google_play_store, :with_staged_rollout, step: release_step) }
    let(:release) { create(:release, train:) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release_platform:, release:) }

    it "is false when it has step run and production deployment run has not started rollout" do
      release_step_run = create(:step_run, step: release_step, release_platform_run:)
      create(:deployment_run, deployment: production_deployment, step_run: release_step_run)
      release_platform_run.bump_version!
      expect(release_platform_run).not_to be_release_fix
    end

    it "is true when it has step run and production deployment run has started rollout" do
      release_step_run = create(:step_run, step: release_step, release_platform_run:)
      create(:deployment_run, :rollout_started, deployment: production_deployment, step_run: release_step_run)
      release_platform_run.bump_version!
      expect(release_platform_run).to be_release_fix
    end

    it "is false release train is finished" do
      release_platform_run.update(status: "finished")
      expect(release_platform_run).not_to be_release_fix
    end
  end

  describe "#version_bump_required?" do
    context "when android app" do
      let(:app) { create(:app, :android) }
      let(:train) { create(:train, app:) }
      let(:release_platform) { create(:release_platform, train:) }
      let(:review_step) { create(:step, :review, :with_deployment, release_platform:) }
      let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
      let(:regular_deployment) { create(:deployment, :with_google_play_store, step: release_step) }
      let(:production_deployment) { create(:deployment, :with_google_play_store, :with_staged_rollout, step: release_step) }
      let(:release) { create(:release, train:) }
      let(:release_platform_run) { create(:release_platform_run, :on_track, release_platform:, release:) }

      it "is false when it does not have a release step run" do
        _review_step_run = create(:step_run, step: review_step, release_platform_run:)
        expect(release_platform_run).not_to be_version_bump_required
      end

      it "is false when it has a release step run but no production deployment run" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, deployment: regular_deployment, step_run: release_step_run)
        expect(release_platform_run).not_to be_version_bump_required
      end

      it "is false when it has step run and production deployment run has not started rollout" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, deployment: production_deployment, step_run: release_step_run)
        expect(release_platform_run).not_to be_version_bump_required
      end

      it "is true when it has step run and production deployment run has started rollout" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, :rollout_started, deployment: production_deployment, step_run: release_step_run)
        expect(release_platform_run).to be_version_bump_required
      end

      it "is false release train is finished" do
        release_platform_run.update(status: "finished")
        expect(release_platform_run.metadata_editable?).to be(false)
      end

      it "is true when rollout has started for production deployment" do
        expect(release_platform_run.metadata_editable?).to be(true)
      end
    end

    context "when iOS app" do
      let(:app) { create(:app, :ios) }
      let(:train) { create(:train, app:) }
      let(:release_platform) { create(:release_platform, train:, platform: app.platform) }
      let(:review_step) { create(:step, :review, :with_deployment, release_platform:) }
      let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
      let(:regular_deployment) { create(:deployment, :with_app_store, step: release_step) }
      let(:production_deployment) { create(:deployment, :with_app_store, :with_phased_release, step: release_step) }
      let(:release) { create(:release, train:) }
      let(:release_platform_run) { create(:release_platform_run, :on_track, release_platform:, release:) }

      it "is false when it does not have a release step run" do
        _review_step_run = create(:step_run, step: review_step, release_platform_run:)
        expect(release_platform_run).not_to be_version_bump_required
      end

      it "is false when it has a release step run but no production deployment run" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, deployment: regular_deployment, step_run: release_step_run)
        expect(release_platform_run).not_to be_version_bump_required
      end

      it "is false when it has step run and production deployment run has not started rollout" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, deployment: production_deployment, step_run: release_step_run)
        expect(release_platform_run).not_to be_version_bump_required
      end

      it "is true when it has step run and production deployment run has started rollout" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, :rollout_started, deployment: production_deployment, step_run: release_step_run)
        expect(release_platform_run).to be_version_bump_required
      end

      it "is true when it has step run and production deployment run has been review approved" do
        release_step_run = create(:step_run, step: release_step, release_platform_run:)
        create(:deployment_run, :ready_to_release, deployment: production_deployment, step_run: release_step_run)
        expect(release_platform_run).to be_version_bump_required
      end
    end
  end

  describe "#bump_version!" do
    let(:app) { create(:app, :android) }
    let(:train) { create(:train, app:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
    let(:release) { create(:release, train:) }

    [[:with_google_play_store, :with_production_channel],
      [:with_google_play_store, :with_staged_rollout],
      [:with_app_store, :with_production_channel],
      [:with_app_store, :with_phased_release]].each do |test_case|
      test_case_help = test_case.join(", ").humanize.downcase

      it "updates the minor version if the current version is a partial semver with #{test_case_help}" do
        release_version = "1.2"
        deployment = create(:deployment, *test_case, step: release_step)
        release_platform_run = create(:release_platform_run, :on_track, release_platform:, release:, release_version:)
        step_run = create(:step_run, release_platform_run:, step: release_step)
        create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

        release_platform_run.bump_version!
        release_platform_run.reload

        expect(release_platform_run.release_version).to eq("1.3")
      end

      it "updates the patch version if the current version is a proper semver with #{test_case_help}" do
        release_version = "1.2.3"
        deployment = create(:deployment, *test_case, step: release_step)
        release_platform_run = create(:release_platform_run, :on_track, release_platform:, release:, release_version:)
        step_run = create(:step_run, release_platform_run:, step: release_step)
        create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

        release_platform_run.bump_version!
        release_platform_run.reload

        expect(release_platform_run.release_version).to eq("1.2.4")
      end
    end

    it "does not do anything if no production deployments" do
      release_version = "1.2.3"
      release_platform_run = create(:release_platform_run, :on_track, release_platform:, release:, release_version:)
      step_run = create(:step_run, step: release_step, release_platform_run:)
      create(:deployment_run, step_run: step_run)

      expect {
        release_platform_run.bump_version!
      }.not_to change { release_platform_run.release_version }
    end

    context "when upcoming release and proper semver" do
      let(:ongoing_release_version) { "1.2.3" }
      let(:upcoming_release_version) { "1.3.0" }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }
      let(:upcoming_release) { create(:release, :with_no_platform_runs, train:, original_release_version: upcoming_release_version) }

      it "bumps patch version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release:, release_version: ongoing_release_version)
        deployment = create(:deployment, :with_google_play_store, :with_production_channel, step: release_step)
        _upcoming_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: upcoming_release, release_version: upcoming_release_version)
        step_run = create(:step_run, release_platform_run: ongoing_release_platform_run, step: release_step)
        create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

        ongoing_release_platform_run.bump_version!
        ongoing_release_platform_run.reload

        expect(ongoing_release_platform_run.release_version).to eq("1.2.4")
      end
    end

    context "when upcoming release and partial semver" do
      let(:ongoing_release_version) { "1.2" }
      let(:upcoming_release_version) { "1.3" }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }
      let(:upcoming_release) { create(:release, :with_no_platform_runs, train:, original_release_version: upcoming_release_version) }

      it "bumps version to higher than current upcoming release version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)
        deployment = create(:deployment, :with_google_play_store, :with_production_channel, step: release_step)
        _upcoming_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: upcoming_release, release_version: upcoming_release_version)
        step_run = create(:step_run, release_platform_run: ongoing_release_platform_run, step: release_step)
        create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

        ongoing_release_platform_run.bump_version!
        ongoing_release_platform_run.reload

        expect(ongoing_release_platform_run.release_version).to eq("1.4")
      end
    end

    context "when no upcoming release and partial semver" do
      let(:ongoing_release_version) { "1.2" }
      let(:ongoing_release) { create(:release, :with_no_platform_runs, train:, original_release_version: ongoing_release_version) }

      it "bumps version to next release version" do
        ongoing_release_platform_run = create(:release_platform_run, :on_track, release_platform:, release: ongoing_release, release_version: ongoing_release_version)
        deployment = create(:deployment, :with_google_play_store, :with_production_channel, step: release_step)
        step_run = create(:step_run, release_platform_run: ongoing_release_platform_run, step: release_step)
        create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

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
    let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }

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
  end

  describe "#on_finish!" do
    it "schedules a platform-specific tag job if cross-platform app" do
      app = create(:app, :cross_platform)
      train = create(:train, app:, tag_platform_releases: true)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_platform:)
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      release_platform_run.finish!

      expect(ReleasePlatformRuns::CreateTagJob).to have_received(:perform_later).with(release_platform_run.id).once
    end

    it "does not schedule a platform-specific tag job if cross-platform app tagging all store releases" do
      app = create(:app, :cross_platform)
      train = create(:train, app:, tag_platform_releases: true, tag_all_store_releases: true)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_platform:)
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      release_platform_run.finish!

      expect(ReleasePlatformRuns::CreateTagJob).not_to have_received(:perform_later).with(release_platform_run.id)
    end

    it "does not schedule a platform-specific tag job for single-platform apps" do
      app = create(:app, :android)
      train = create(:train, app:)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      release_platform_run = create(:release_platform_run, :on_track, release:, release_platform:)
      allow(ReleasePlatformRuns::CreateTagJob).to receive(:perform_later)

      release_platform_run.finish!

      expect(ReleasePlatformRuns::CreateTagJob).not_to have_received(:perform_later).with(release_platform_run.id)
    end
  end

  describe "#create_tag!" do
    let(:release_platform) { create(:release_platform) }
    let(:step) { create(:step, release_platform:) }
    let(:release) { create(:release) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release:, release_platform:) }

    it "saves a new tag with the base name" do
      allow_any_instance_of(GithubIntegration).to receive(:create_tag!)
      commit = create(:commit, :without_trigger, release:)
      create(:step_run, release_platform_run:, commit:)

      release_platform_run.create_tag!
      expect(release_platform_run.tag_name).to eq("v1.2.3-android")
    end

    it "saves base name + last commit sha" do
      raise_times(GithubIntegration, Installations::Errors::TagReferenceAlreadyExists, :create_tag!, 1)
      commit = create(:commit, :without_trigger, release:)
      create(:step_run, release_platform_run:, commit:)

      release_platform_run.create_tag!
      expect(release_platform_run.tag_name).to eq("v1.2.3-android-#{commit.short_sha}")
    end

    it "saves base name + last commit sha + time" do
      raise_times(GithubIntegration, Installations::Errors::TagReferenceAlreadyExists, :create_tag!, 2)

      freeze_time do
        now = Time.now.to_i
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release_platform_run.create_tag!
        expect(release_platform_run.tag_name).to eq("v1.2.3-android-#{commit.short_sha}-#{now}")
      end
    end
  end
end
