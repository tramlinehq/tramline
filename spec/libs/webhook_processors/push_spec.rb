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
      it "bumps the patch version when its a production store distribution channel" do
        pick_any_store = [:with_google_play_store, :with_app_store].sample
        step = create(:releases_step, :release, :with_deployment, train: train)
        deployment = create(:deployment, :with_production_channel, pick_any_store, step: step)
        step_run = create(:releases_step_run, train_run:, step:)
        _deployment_run = create(:deployment_run, :created, deployment: deployment, step_run: step_run)

        allow(Triggers::StepRun).to receive(:call)
        described_class.process(train_run.reload, commit_attributes)

        expect(train.reload.version_current).to eq("1.6.1")
        expect(train_run.reload.release_version).to eq("1.6.1")
      end

      it "does not bump the original release version even when a patch version bump takes place" do
        pick_any_store = [:with_google_play_store, :with_app_store].sample
        step = create(:releases_step, :release, :with_deployment, train: train)
        deployment = create(:deployment, :with_production_channel, pick_any_store, step: step)
        step_run = create(:releases_step_run, train_run:, step:)
        _deployment_run = create(:deployment_run, :created, deployment: deployment, step_run: step_run)

        allow(Triggers::StepRun).to receive(:call)
        described_class.process(train_run.reload, commit_attributes)

        expect(train_run.reload.release_version).to eq("1.6.1")
        expect(train_run.reload.original_release_version).to eq("1.6.0")
      end

      it "does not bump the patch version when its any other distribution channel" do
        non_store = :with_slack
        step = create(:releases_step, :release, :with_deployment, train: train)
        deployment = create(:deployment, :with_production_channel, non_store, step: step)
        step_run = create(:releases_step_run, train_run:, step:)
        _deployment_run = create(:deployment_run, :created, deployment: deployment, step_run: step_run)

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
