require "rails_helper"

describe Releases::Train::Run do
  it "has a valid factory" do
    expect(create(:releases_train_run)).to be_valid
  end

  describe "#next_step" do
    subject(:run) { create(:releases_train_run) }

    let(:steps) { create_list(:releases_step, 5, :with_deployment, train: run.train) }

    it "returns next step" do
      expect(run.next_step).to be_nil
    end
  end

  describe "#startable_step?" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, :with_deployment, train: active_train) }

    it "first step can be started if there are no step runs" do
      train_run = create(:releases_train_run, train: active_train)

      expect(train_run.startable_step?(steps.first)).to be(true)
      expect(train_run.startable_step?(steps.second)).to be(false)
    end

    it "next step can be started after finishing previous step" do
      train_run = create(:releases_train_run, train: active_train)
      create(:releases_step_run, step: steps.first, status: "success", train_run: train_run)

      expect(train_run.startable_step?(steps.first)).to be(false)
      expect(train_run.startable_step?(steps.second)).to be(true)
    end
  end

  describe "#overall_movement_status" do
    let(:active_train) { create(:releases_train, :active) }

    it "returns the status of every step of the train" do
      steps = create_list(:releases_step, 4, :with_deployment, train: active_train)
      train_run = create(:releases_train_run, train: active_train)
      commit = create(:releases_commit, train_run: train_run)
      _step_run_1 = create(:releases_step_run, commit:, step: steps.first, status: "success", train_run: train_run)
      _step_run_2 = create(:releases_step_run, commit:, step: steps.second, status: "ci_workflow_failed", train_run: train_run)
      _step_run_3 = create(:releases_step_run, commit:, step: steps.third, status: "on_track", train_run: train_run)

      expectation = {
        steps.first => {in_progress: false, done: true, failed: false},
        steps.second => {in_progress: false, done: false, failed: true},
        steps.third => {in_progress: true, done: false, failed: false},
        steps.fourth => {not_started: true}
      }

      expect(train_run.overall_movement_status).to eq(expectation)
    end

    it "always accounts for the last step run of a particular step" do
      steps = create_list(:releases_step, 2, :with_deployment, train: active_train)
      train_run = create(:releases_train_run, train: active_train)
      commit_1 = create(:releases_commit, train_run: train_run)
      commit_2 = create(:releases_commit, train_run: train_run)
      _step_run_1 = create(:releases_step_run, commit: commit_1, step: steps.first, status: "success", train_run: train_run)
      _step_run_1 = create(:releases_step_run, commit: commit_2, step: steps.first, status: "ci_workflow_unavailable", train_run: train_run)
      _step_run_2 = create(:releases_step_run, commit: commit_1, step: steps.second, status: "ci_workflow_failed", train_run: train_run)
      _step_run_2 = create(:releases_step_run, commit: commit_2, step: steps.second, status: "success", train_run: train_run)

      expectation = {
        steps.first => {in_progress: false, done: false, failed: true},
        steps.second => {in_progress: false, done: true, failed: false}
      }

      expect(train_run.overall_movement_status).to eq(expectation)
    end
  end

  describe "finalizable?" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, :with_deployment, train: active_train) }
    let(:train_run) { create(:releases_train_run, train: active_train) }

    it "is finalizable when all the steps for the last commit have succeeded" do
      commit_1 = create(:releases_commit, train_run: train_run)
      _commit_1_fail = create(:releases_step_run, :ci_workflow_failed, commit: commit_1, step: steps.first, train_run: train_run)
      _commit_1_pass = create(:releases_step_run, :success, commit: commit_1, step: steps.second, train_run: train_run)

      commit_2 = create(:releases_commit, train_run: train_run)
      _commit_2_pass = create(:releases_step_run, :success, commit: commit_2, step: steps.first, train_run: train_run)
      _commit_2_pass = create(:releases_step_run, :success, commit: commit_2, step: steps.second, train_run: train_run)

      expect(train_run.finalizable?).to be(true)
    end

    it "is not finalizable when all the steps for the last commit have not succeeded" do
      commit_1 = create(:releases_commit, train_run: train_run)
      _commit_1_pass = create(:releases_step_run, :success, commit: commit_1, step: steps.first, train_run: train_run)
      _commit_1_fail = create(:releases_step_run, :ci_workflow_failed, commit: commit_1, step: steps.second, train_run: train_run)

      commit_2 = create(:releases_commit, train_run: train_run)
      _commit_2_fail = create(:releases_step_run, :ci_workflow_failed, commit: commit_2, step: steps.first, train_run: train_run)
      _commit_2_pass = create(:releases_step_run, :success, commit: commit_2, step: steps.second, train_run: train_run)

      expect(train_run.finalizable?).to be(false)
    end
  end
end
