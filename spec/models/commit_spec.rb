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
      train.update(status: ReleasePlatform.statuses[:active])
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:commit, release:)

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

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, release_platform_run).once
      expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, release_platform_run).once
    end
  end
end
