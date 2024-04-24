require "rails_helper"

describe Commit do
  it "has valid factory" do
    expect(create(:commit)).to be_valid
  end

  describe "#trigger_step_runs" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }

    context "when latest commit" do
      it "does it for the first step run if first commit" do
        steps = create_list(:step, 2, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        commit = create(:commit, release:)

        allow(release).to receive(:latest_commit_hash).and_return(commit.commit_hash)
        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs

        expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
      end

      it "does it for all steps until the currently running one" do
        steps = create_list(:step, 2, :with_deployment, release_platform:)
        release = create(:release, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        create(:step_run, :success, step: steps.first, release_platform_run:)
        create(:step_run, step: steps.second, release_platform_run:)
        commit = create(:commit, release:)

        allow(release).to receive(:latest_commit_hash).and_return(commit.commit_hash)
        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs

        expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
        expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, release_platform_run).once
      end

      it "does not trigger release step if manual release is configured" do
        train = create(:train, manual_release: true)
        release_platform = create(:release_platform, train:)
        steps = create_list(:step, 2, :with_deployment, release_platform:)
        release_step = create(:step, :release, :with_deployment, release_platform:)
        release = create(:release, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        create(:step_run, :success, step: steps.first, release_platform_run:)
        create(:step_run, step: steps.second, release_platform_run:)
        create(:step_run, step: release_step, release_platform_run:)
        commit = create(:commit, release:)

        allow(release).to receive(:latest_commit_hash).and_return(commit.commit_hash)
        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs

        expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
        expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, release_platform_run).once
        expect(Triggers::StepRun).not_to have_received(:call).with(release_step, commit, release_platform_run)
      end

      it "triggers release step if manual release is configured but there are no review steps" do
        train = create(:train, manual_release: true)
        release_platform = create(:release_platform, train:)
        release_step = create(:step, :release, :with_deployment, release_platform:)
        release = create(:release, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        commit = create(:commit, release:)

        allow(release).to receive(:latest_commit_hash).and_return(commit.commit_hash)
        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs

        expect(Triggers::StepRun).to have_received(:call).with(release_step, commit, release_platform_run).once
      end
    end

    context "when not latest commit" do
      it "does not trigger step runs if commit is not applicable" do
        create_list(:step, 2, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        create(:release_platform_run, release_platform:, release:)

        allow(release).to receive(:latest_commit_hash).and_return("new_commit")
        allow(Triggers::StepRun).to receive(:call)

        commit = create(:commit, release:)
        commit.trigger_step_runs

        expect(Triggers::StepRun).not_to have_received(:call)
      end
    end

    context "when hotfix release" do
      it "does not trigger steps" do
        _steps = create_list(:step, 2, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        commit = create(:commit, release:)

        allow(release).to receive(:latest_commit_hash).and_return(commit.commit_hash)
        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs

        expect(Triggers::StepRun).not_to have_received(:call)
      end
    end
  end

  describe ".commit_messages" do
    it "returns commit messages" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1")
      commit2 = create(:commit, release:, message: "commit2")

      expect(release.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message)
    end

    it "returns first parent commit messages when no parent defined" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1")
      commit2 = create(:commit, release:, message: "commit2")

      expect(release.all_commits.commit_messages(true)).to contain_exactly(commit1.message, commit2.message)
    end

    it "returns first parent commit messages when parents defined" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1", parents: [{sha: "parent_sha"}])
      commit2 = create(:commit, release:, message: "commit2", parents: [{sha: commit1.commit_hash}])

      expect(release.all_commits.commit_messages(true)).to contain_exactly(commit1.message, commit2.message)
    end

    it "skips messages which are not first parent" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1", parents: [{sha: "parent_sha"}]) # new feature branch of main
      commit2 = create(:commit, release:, message: "commit2", parents: [{sha: "parent_sha"}]) # new commit on main
      commit3 = create(:commit, release:, message: "commit3", parents: [{sha: commit1.commit_hash}]) # feature branch commit
      commit4 = create(:commit, release:, message: "commit4", parents: [{sha: commit2.commit_hash}, {sha: commit3.commit_hash}]) # merge of feature branch to main

      expect(release.all_commits.commit_messages(true)).to contain_exactly(commit2.message, commit4.message)
    end

    it "does not skip messages when first parent is not true" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1", parents: [{sha: "parent_sha"}]) # new feature branch of main
      commit2 = create(:commit, release:, message: "commit2", parents: [{sha: "parent_sha"}]) # new commit on main
      commit3 = create(:commit, release:, message: "commit3", parents: [{sha: commit1.commit_hash}]) # feature branch commit
      commit4 = create(:commit, release:, message: "commit4", parents: [{sha: commit2.commit_hash}, {sha: commit3.commit_hash}]) # merge of feature branch to main

      expect(release.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message, commit3.message, commit4.message)
    end
  end

  describe ".between" do
    it "returns empty association if both step runs are nil" do
      expect(described_class.between(nil, nil)).to be_none
    end

    it "returns empty association if head step run is nil" do
      expect(described_class.between(create(:step_run), nil)).to be_none
    end

    it "returns all commits till the current step if starting step run is nil" do
      release_platform = create(:release_platform)
      step = create(:step, :with_deployment, release_platform: release_platform)
      release_platform_run = create(:release_platform_run, release_platform:)
      release = release_platform_run.release
      run1 = create(:step_run, :build_available, step:, release_platform_run:, commit: create(:commit, release:))
      run2 = create(:step_run, :build_available, step:, release_platform_run:, commit: create(:commit, release:))
      run3 = create(:step_run, :build_not_found_in_store, step:, release_platform_run:, commit: create(:commit, release:))
      end_run = create(:step_run, :success, step:, release_platform_run:, commit: create(:commit, release:))
      _run4 = create(:step_run, :success, step:, release_platform_run:, commit: create(:commit, release:))

      expect(described_class.between(nil, end_run)).to contain_exactly(run1.commit, run2.commit, run3.commit, end_run.commit)
    end

    it "returns all commits between two step runs" do
      release_platform = create(:release_platform)
      step = create(:step, :with_deployment, release_platform: release_platform)
      release_platform_run = create(:release_platform_run, release_platform:)
      release = release_platform_run.release
      start_run = create(:step_run, :success, step:, release_platform_run:, commit: create(:commit, release:))
      run2 = create(:step_run, :build_available, step:, release_platform_run:, commit: create(:commit, release:))
      run3 = create(:step_run, :build_not_found_in_store, step:, release_platform_run:, commit: create(:commit, release:))
      end_run = create(:step_run, :success, step:, release_platform_run:, commit: create(:commit, release:))

      expect(described_class.between(start_run, end_run)).to contain_exactly(run2.commit, run3.commit, end_run.commit)
    end
  end

  describe "#trigger!" do
    context "when no build queue" do
      let(:train) { create(:train) }
      let(:release_platform) { create(:release_platform, train:) }

      it "triggers step runs if no build queue is present" do
        step = create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)

        allow(Triggers::StepRun).to receive(:call)

        commit = create(:commit, release:)
        commit.trigger!

        expect(Triggers::StepRun).to have_received(:call).with(step, commit, release_platform_run).once
      end
    end

    context "when build queue" do
      let(:train) { create(:train, :with_build_queue) }
      let(:release_platform) { create(:release_platform, train:) }

      it "triggers step runs when commit is the first commit" do
        step = create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)

        allow(Triggers::StepRun).to receive(:call)

        commit = create(:commit, release:)
        commit.trigger!

        expect(Triggers::StepRun).to have_received(:call).with(step, commit, release_platform_run).once
      end

      it "does not trigger step runs when commit is not the first commit" do
        create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        create(:release_platform_run, release_platform:, release:)
        _older_commit = create(:commit, release:)

        allow(Triggers::StepRun).to receive(:call)

        commit = create(:commit, release:)
        commit.trigger!

        expect(Triggers::StepRun).not_to have_received(:call)
      end

      it "adds to the build queue when commit is not the first commit" do
        create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        create(:release_platform_run, release_platform:, release:)
        _older_commit = create(:commit, release:)

        commit = create(:commit, release:)
        commit.trigger!

        expect(commit.reload.build_queue).to eql(release.active_build_queue)
      end
    end
  end

  describe "#add_to_build_queue!" do
    context "when no build queue" do
      let(:train) { create(:train) }
      let(:release_platform) { create(:release_platform, train:) }

      it "does nothing when no build queue" do
        create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        create(:release_platform_run, release_platform:, release:)

        commit = create(:commit, release:)
        commit.add_to_build_queue!

        expect(commit.reload.build_queue).to be_nil
      end
    end

    context "when build queue" do
      let(:train) { create(:train, :with_build_queue) }
      let(:release_platform) { create(:release_platform, train:) }

      it "does nothing when commit is the first commit" do
        create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        create(:release_platform_run, release_platform:, release:)

        commit = create(:commit, release:)
        commit.add_to_build_queue!

        expect(commit.reload.build_queue).to be_nil
      end

      it "adds to the build queue when commit is not the first commit" do
        create(:step, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        release = create(:release, train:)
        create(:release_platform_run, release_platform:, release:)
        _older_commit = create(:commit, release:)

        commit = create(:commit, release:)
        commit.add_to_build_queue!

        expect(commit.reload.build_queue).to eql(release.active_build_queue)
      end
    end
  end

  describe "#trigger_step_runs_for" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }

    it "updates the last commit of the release platform run" do
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      commit = create(:commit, release:)

      allow(Triggers::StepRun).to receive(:call)
      commit.trigger_step_runs_for(release_platform_run)

      expect(release_platform_run.reload.last_commit).to eq(commit)
    end

    it "does it for the first step run if first commit" do
      steps = create_list(:step, 2, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      commit = create(:commit, release:)

      allow(Triggers::StepRun).to receive(:call)

      commit.trigger_step_runs_for(release_platform_run)

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
    end

    it "does it for all steps until the currently running one" do
      steps = create_list(:step, 2, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      create(:step_run, :success, step: steps.first, release_platform_run:)
      create(:step_run, step: steps.second, release_platform_run:)
      commit = create(:commit, release:)

      allow(Triggers::StepRun).to receive(:call)

      commit.trigger_step_runs

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
      expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, release_platform_run).once
    end

    it "does not trigger release step if manual release is configured" do
      train = create(:train, manual_release: true)
      release_platform = create(:release_platform, train:)
      steps = create_list(:step, 2, :with_deployment, release_platform:)
      release_step = create(:step, :release, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      create(:step_run, :success, step: steps.first, release_platform_run:)
      create(:step_run, step: steps.second, release_platform_run:)
      create(:step_run, step: release_step, release_platform_run:)
      commit = create(:commit, release:)

      allow(Triggers::StepRun).to receive(:call)

      commit.trigger_step_runs_for(release_platform_run)

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
      expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, release_platform_run).once
      expect(Triggers::StepRun).not_to have_received(:call).with(release_step, commit, release_platform_run)
    end

    it "triggers release step if manual release is configured but there are no review steps" do
      train = create(:train, manual_release: true)
      release_platform = create(:release_platform, train:)
      release_step = create(:step, :release, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      commit = create(:commit, release:)

      allow(Triggers::StepRun).to receive(:call)

      commit.trigger_step_runs_for(release_platform_run)

      expect(Triggers::StepRun).to have_received(:call).with(release_step, commit, release_platform_run).once
    end

    context "when hotfix release" do
      it "does not trigger steps" do
        _steps = create_list(:step, 2, :with_deployment, release_platform:)
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        commit = create(:commit, release:)

        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs_for(release_platform_run)

        expect(Triggers::StepRun).not_to have_received(:call)
      end

      it "does not update the last commit of the release platform run" do
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        commit = create(:commit, release:)

        commit.trigger_step_runs_for(release_platform_run)

        expect(release_platform_run.reload.last_commit).to be_nil
      end
    end

    context "when hotfix release and force true" do
      it "does not trigger steps" do
        _steps = create_list(:step, 2, :with_deployment, release_platform:)
        train.update(status: Train.statuses[:active])
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        commit = create(:commit, release:)

        allow(Triggers::StepRun).to receive(:call)

        commit.trigger_step_runs_for(release_platform_run, force: true)

        expect(Triggers::StepRun).not_to have_received(:call)
      end

      it "updates the last commit of the release platform run" do
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        commit = create(:commit, release:)

        commit.trigger_step_runs_for(release_platform_run, force: true)

        expect(release_platform_run.reload.last_commit).to eq(commit)
      end
    end
  end
end
