require "rails_helper"

describe WebhookProcessors::Push do
  let(:train) { create(:releases_train, version_seeded_with: "1.5.0") }
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
    let(:train_run) { create(:releases_train_run, :created, train: train) }

    it "does not bump the patch version for first commit" do
      described_class.process(train_run, commit_attributes)

      expect(train.reload.version_current).to eq("1.6.0")
      expect(train_run.reload.release_version).to eq("1.6.0")
    end

    context "when hotfix" do
      [[:with_google_play_store, :with_production_channel],
        [:with_google_play_store, :with_staged_rollout],
        [:with_app_store, :with_production_channel],
        [:with_app_store, :with_phased_release]].each do |test_case|
        test_case_help = test_case.join(", ").humanize.downcase
        it "bumps the patch version #{test_case_help} in rollout mode" do
          step = create(:releases_step, :release, :with_deployment, train: train)
          deployment = create(:deployment, *test_case, step: step)
          step_run = create(:releases_step_run, train_run:, step:)
          _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

          allow(Triggers::StepRun).to receive(:call)
          described_class.process(train_run.reload, commit_attributes)

          expect(train.reload.version_current).to eq("1.6.1")
          expect(train_run.reload.release_version).to eq("1.6.1")
        end

        it "does not bump the original release version for a patch version bump #{test_case_help}" do
          step = create(:releases_step, :release, :with_deployment, train: train)
          deployment = create(:deployment, *test_case, step: step)
          step_run = create(:releases_step_run, train_run:, step:)
          _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

          allow(Triggers::StepRun).to receive(:call)
          described_class.process(train_run.reload, commit_attributes)

          expect(train_run.reload.release_version).to eq("1.6.1")
          expect(train_run.reload.original_release_version).to eq("1.6.0")
        end
      end

      it "does not bump the patch version when its any other distribution channel" do
        non_store = :with_slack
        step = create(:releases_step, :release, :with_deployment, train: train)
        deployment = create(:deployment, :with_production_channel, non_store, step: step)
        step_run = create(:releases_step_run, train_run:, step:)
        _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)

        allow(Triggers::StepRun).to receive(:call)
        described_class.process(train_run.reload, commit_attributes)

        expect(train.reload.version_current).to eq("1.6.0")
        expect(train_run.reload.release_version).to eq("1.6.0")
      end
    end

    it "starts the release" do
      described_class.process(train_run, commit_attributes)

      expect(train_run.reload.on_track?).to be(true)
    end

    it "creates a new commit" do
      expect {
        described_class.process(train_run, commit_attributes)
      }.to change(Releases::Commit, :count)
    end

    it "triggers step runs" do
      step = create(:releases_step, :with_deployment, train: train)
      _step_run = create(:releases_step_run, train_run:, step:)
      allow(Triggers::StepRun).to receive(:call)

      described_class.process(train_run, commit_attributes)

      expect(Triggers::StepRun).to have_received(:call).once
    end
  end
end
