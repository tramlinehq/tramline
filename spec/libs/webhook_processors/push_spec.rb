require "rails_helper"

describe WebhookProcessors::Push do
  let(:train) { create(:train, version_seeded_with: "1.5.0") }
  let(:commit_attributes) do
    {
      commit_sha: "1",
      message: Faker::Lorem.sentence,
      timestamp: Time.current,
      author_name: Faker::Name.name,
      author_email: Faker::Internet.email,
      url: Faker::Internet.url,
      branch_name: Faker::Lorem.word
    }
  end

  describe "#process" do
    let(:release) { create(:release, :created, train: train) }

    it "does not bump the patch version for first commit" do
      described_class.process(release, commit_attributes)

      expect(train.reload.version_current).to eq("1.6.0")
      expect(release.reload.release_version).to eq("1.6.0")
    end

    context "when hotfix" do
      [[:with_google_play_store, :with_production_channel],
        [:with_google_play_store, :with_staged_rollout],
        [:with_app_store, :with_production_channel],
        [:with_app_store, :with_phased_release]].each do |test_case|
        test_case_help = test_case.join(", ").humanize.downcase
        it "bumps the patch version #{test_case_help} in rollout mode" do
          release_platform = create(:release_platform, train: train)
          release_platform_run = create(:release_platform_run, release_platform:, release:)
          step = create(:step, :release, :with_deployment, release_platform:)
          deployment = create(:deployment, *test_case, step: step)
          step_run = create(:step_run, release_platform_run:, step:)
          _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

          allow(Triggers::StepRun).to receive(:call)
          described_class.process(release.reload, commit_attributes)

          expect(train.reload.version_current).to eq("1.6.1")
          expect(release.reload.release_version).to eq("1.6.1")
        end

        it "does not bump the original release version for a patch version bump #{test_case_help}" do
          release_platform = create(:release_platform, train: train)
          release_platform_run = create(:release_platform_run, release_platform:, release:)
          step = create(:step, :release, :with_deployment, release_platform:)
          deployment = create(:deployment, *test_case, step: step)
          step_run = create(:step_run, release_platform_run:, step:)
          _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

          allow(Triggers::StepRun).to receive(:call)
          described_class.process(release.reload, commit_attributes)

          expect(release.reload.release_version).to eq("1.6.1")
          expect(release.reload.original_release_version).to eq("1.6.0")
        end
      end

      it "does not bump the patch version when its any other distribution channel" do
        non_store = :with_slack
        release_platform = create(:release_platform, train: train)
        release_platform_run = create(:release_platform_run, release_platform:, release:)
        step = create(:step, :release, :with_deployment, release_platform:)
        deployment = create(:deployment, :with_production_channel, non_store, step: step)
        step_run = create(:step_run, release_platform_run:, step:)
        _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

        allow(Triggers::StepRun).to receive(:call)
        described_class.process(release.reload, commit_attributes)

        expect(train.reload.version_current).to eq("1.6.0")
        expect(release.reload.release_version).to eq("1.6.0")
      end
    end

    it "starts the release" do
      described_class.process(release, commit_attributes)

      expect(release.reload.on_track?).to be(true)
    end

    it "creates a new commit" do
      expect {
        described_class.process(release, commit_attributes)
      }.to change(Commit, :count)
    end

    it "triggers step runs" do
      release_platform = create(:release_platform, train: train)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      step = create(:step, :with_deployment, release_platform:)
      _step_run = create(:step_run, release_platform_run:, step:)
      allow(Triggers::StepRun).to receive(:call)

      described_class.process(release, commit_attributes)

      expect(Triggers::StepRun).to have_received(:call).once
    end
  end
end
