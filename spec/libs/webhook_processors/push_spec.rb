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

    context "when production submission has happened" do
      [[:with_google_play_store, :with_production_channel, :rollout_started],
        [:with_google_play_store, :with_staged_rollout, :rollout_started],
        [:with_app_store, :with_production_channel, :submitted_for_review],
        [:with_app_store, :with_production_channel, :rollout_started],
        [:with_app_store, :with_production_channel, :review_failed],
        [:with_app_store, :with_phased_release, :submitted_for_review],
        [:with_app_store, :with_phased_release, :rollout_started],
        [:with_app_store, :with_phased_release, :review_failed]].each do |test_case|
        test_case_help = test_case.join(", ").humanize.downcase

        it "does not trigger step runs for the platform run #{test_case_help}" do
          deployment_traits = test_case[0..1]
          deployment_run_trait = test_case.last
          deployment = create(:deployment, *deployment_traits, step: step)
          step_run = create(:step_run, release_platform_run:, step:)
          _deployment_run = create(:deployment_run, deployment_run_trait, deployment: deployment, step_run: step_run)
          allow(Triggers::StepRun).to receive(:call)
          described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

          expect(Triggers::StepRun).not_to have_received(:call)
        end
      end
    end

    context "when hotfix release" do
      it "does not trigger step runs for the platform run for the first commit" do
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        allow(Triggers::StepRun).to receive(:call)
        described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

        expect(Triggers::StepRun).not_to have_received(:call)
      end

      it "does not trigger step runs for the platform run for subsequent commit" do
        _older_release = create(:release, :finished, train:)
        release = create(:release, :hotfix, train:)
        deployment = create(:deployment, :with_google_play_store, step: step)
        step_run = create(:step_run, release_platform_run:, step:)
        _deployment_run = create(:deployment_run, :rollout_started, deployment: deployment, step_run: step_run)
        allow(Triggers::StepRun).to receive(:call)
        described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

        expect(Triggers::StepRun).not_to have_received(:call)
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

    context "when build queue" do
      let(:queue_size) { 3 }
      let(:train) { create(:train, :with_build_queue, version_seeded_with: "1.5.0", build_queue_size: queue_size) }
      let(:release) { create(:release, :with_no_platform_runs, :on_track, train: train) }
      let(:release_platform) { create(:release_platform, train: train) }

      it "triggers step run for the first commit" do
        create(:step, :with_deployment, release_platform:)
        create(:release_platform_run, release_platform:, release:, release_version: train.version_current)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, [])

        expect(Triggers::StepRun).to have_received(:call).once
      end

      it "adds the subsequent commits to the queue" do
        _old_commit = create(:commit, release:, timestamp: 1.minute.ago)
        create(:step, :with_deployment, release_platform:)
        create(:release_platform_run, release_platform:, release:, release_version: train.version_current)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, [])

        expect(Triggers::StepRun).not_to have_received(:call)
        expect(release.applied_commits.reload.size).to be(1)
        expect(release.all_commits.reload.last.build_queue).to eql(release.active_build_queue)
      end

      it "adds all commits to the queue when multiple commits" do
        old_commit = create(:commit, release:)
        create(:step, :with_deployment, release_platform:)
        create(:release_platform_run, release_platform:, release:, release_version: train.version_current)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, rest_commit_attributes.take(1))

        expect(release.applied_commits.reload.size).to be(1)
        expect(release.all_commits.reload.size).to be(3)
        release.all_commits.where.not(id: old_commit.id).each do |c|
          expect(c.build_queue).to eq(release.active_build_queue)
        end
      end

      it "applies the build queue if head commit crosses the queue size" do
        _old_commit = create(:commit, release:)
        create(:step, :with_deployment, release_platform:)
        create(:release_platform_run, release_platform:, release:, release_version: train.version_current)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, rest_commit_attributes)

        expect(Triggers::StepRun).to have_received(:call).once
      end

      it "does not apply the build queue if head commit does not cross the queue size" do
        _old_commit = create(:commit, release:)
        create(:step, :with_deployment, release_platform:)
        create(:release_platform_run, release_platform:, release:, release_version: train.version_current)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, rest_commit_attributes.take(1))

        expect(Triggers::StepRun).not_to have_received(:call)
      end
    end
  end
end
