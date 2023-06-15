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

  describe "#startable_step?" do
    let(:release_platform) { create(:release_platform) }
    let(:steps) { create_list(:step, 2, :with_deployment, release_platform:) }

    it "first step can be started if there are no step runs" do
      release_platform_run = create(:release_platform_run, release_platform:)

      expect(release_platform_run.startable_step?(steps.first)).to be(true)
      expect(release_platform_run.startable_step?(steps.second)).to be(false)
    end

    it "next step can be started after finishing previous step" do
      release_platform_run = create(:release_platform_run, release_platform: release_platform)
      create(:step_run, step: steps.first, status: "success", release_platform_run: release_platform_run)

      expect(release_platform_run.startable_step?(steps.first)).to be(false)
      expect(release_platform_run.startable_step?(steps.second)).to be(true)
    end
  end

  describe "#overall_movement_status" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release) { create(:release, train:) }

    it "returns the status of every step of the train" do
      puts train.ci_cd_provider.attributes
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
    let(:steps) { create_list(:step, 2, :with_deployment, release_platform:) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }

    it "is finalizable when all the steps for the last commit have succeeded" do
      commit_1 = create(:commit, release: release_platform_run.release)
      _commit_1_fail = create(:step_run, :ci_workflow_failed, commit: commit_1, step: steps.first, release_platform_run:)
      _commit_1_pass = create(:step_run, :success, commit: commit_1, step: steps.second, release_platform_run:)

      commit_2 = create(:commit, release: release_platform_run.release)
      _commit_2_pass = create(:step_run, :success, commit: commit_2, step: steps.first, release_platform_run:)
      _commit_2_pass = create(:step_run, :success, commit: commit_2, step: steps.second, release_platform_run:)

      expect(release_platform_run.finalizable?).to be(true)
    end

    it "is not finalizable when all the steps for the last commit have not succeeded" do
      commit_1 = create(:commit, release: release_platform_run.release)
      _commit_1_pass = create(:step_run, :success, commit: commit_1, step: steps.first, release_platform_run:)
      _commit_1_fail = create(:step_run, :ci_workflow_failed, commit: commit_1, step: steps.second, release_platform_run:)

      commit_2 = create(:commit, release: release_platform_run.release)
      _commit_2_fail = create(:step_run, :ci_workflow_failed, commit: commit_2, step: steps.first, release_platform_run:)
      _commit_2_pass = create(:step_run, :success, commit: commit_2, step: steps.second, release_platform_run:)

      expect(release_platform_run.finalizable?).to be(false)
    end
  end

  describe "#hotfix?" do
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
      train.bump_fix!
      release.update!(release_version: train.version_current)
      expect(release_platform_run).not_to be_hotfix
    end

    it "is true when it has step run and production deployment run has started rollout" do
      release_step_run = create(:step_run, step: release_step, release_platform_run:)
      create(:deployment_run, :rollout_started, deployment: production_deployment, step_run: release_step_run)
      train.bump_fix!
      release.update!(release_version: train.version_current)
      expect(release_platform_run).not_to be_hotfix
    end

    it "is false release train is finished" do
      release_platform_run.update(status: "finished")
      expect(release_platform_run).not_to be_hotfix
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
end
