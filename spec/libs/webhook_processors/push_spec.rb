require "rails_helper"

describe WebhookProcessors::Push do
  let(:train) { create(:train, version_seeded_with: "1.5.0") }
  let(:head_commit_attributes) do
    {
      commit_hash: "3",
      message: Faker::Lorem.sentence,
      timestamp: Time.current,
      author_name: Faker::Name.name,
      author_email: Faker::Internet.email,
      url: Faker::Internet.url,
      branch_name: Faker::Lorem.word
    }
  end
  let(:rest_commit_attributes) do
    [
      {
        commit_hash: "2",
        message: Faker::Lorem.sentence,
        timestamp: Time.current,
        author_name: Faker::Name.name,
        author_email: Faker::Internet.email,
        url: Faker::Internet.url,
        branch_name: Faker::Lorem.word
      },
      {
        commit_hash: "1",
        message: Faker::Lorem.sentence,
        timestamp: Time.current,
        author_name: Faker::Name.name,
        author_email: Faker::Internet.email,
        url: Faker::Internet.url,
        branch_name: Faker::Lorem.word
      }
    ]
  end

  describe "#process" do
    let(:release) { create(:release, :with_no_platform_runs, :created, train: train) }
    let(:release_platform) { create(:release_platform, train: train) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:, release:, release_version: train.version_current) }
    let(:step) { create(:step, :release, :with_deployment, release_platform:) }

    context "when production deployment has happened" do
      [[:with_google_play_store, :with_production_channel],
        [:with_google_play_store, :with_staged_rollout],
        [:with_app_store, :with_production_channel],
        [:with_app_store, :with_phased_release]].each do |test_case|
        test_case_help = test_case.join(", ").humanize.downcase

        it "does not trigger step runs for the platform run #{test_case_help}" do
          deployment = create(:deployment, *test_case, step: step)
          step_run = create(:step_run, release_platform_run:, step:)
          _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)
          allow(Triggers::StepRun).to receive(:call)
          described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

          expect(Triggers::StepRun).not_to have_received(:call)
        end
      end
    end

    it "starts the release" do
      described_class.process(release, head_commit_attributes, rest_commit_attributes)

      expect(release.reload.on_track?).to be(true)
    end

    it "creates a new commit" do
      expect {
        described_class.process(release, head_commit_attributes, rest_commit_attributes)
      }.to change(Commit, :count)
    end

    it "creates multiple commits if present" do
      described_class.process(release, head_commit_attributes, rest_commit_attributes)

      expect(Commit.count).to eq(3)
    end

    it "creates only the head commit if none other" do
      described_class.process(release, head_commit_attributes, [])

      expect(Commit.count).to eq(1)
    end

    it "triggers step runs" do
      release_platform = train.release_platforms.first
      _release_platform_run = create(:release_platform_run, release_platform:, release:, release_version: train.version_current)
      create(:step, :with_deployment, release_platform:)
      allow(Triggers::StepRun).to receive(:call)

      described_class.process(release, head_commit_attributes, rest_commit_attributes)

      expect(Triggers::StepRun).to have_received(:call).once
    end
  end
end
