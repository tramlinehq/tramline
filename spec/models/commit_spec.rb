require "rails_helper"

describe Commit do
  it "has valid factory" do
    expect(create(:commit)).to be_valid
  end

  describe "#trigger_step_runs" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }

    it "does it for the first step run if first commit" do
      step = create(:step, :with_deployment, release_platform:)
      train.update(status: Train.statuses[:active])
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:commit, release:)
      commit.trigger_step_runs

      expect(Triggers::StepRun).to have_received(:call).with(step, commit, release_platform_run).once
    end

    it "does it for all steps until the currently running one" do
      steps = create_list(:step, 2, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      create(:step_run, :success, step: steps.first, release_platform_run:)
      create(:step_run, step: steps.second, release_platform_run:)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:commit, release:)
      commit.trigger_step_runs

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
      expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, release_platform_run).once
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
end
