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

  before do
    allow_any_instance_of(described_class).to receive(:commit_log).and_return([])
  end

  describe "#process" do
    context "when production submission has happened" do
      [[:android, :with_google_play_store, :with_production_channel, :rollout_started],
        [:android, :with_google_play_store, :with_staged_rollout, :rollout_started],
        [:ios, :with_app_store, :with_production_channel, :submitted_for_review],
        [:ios, :with_app_store, :with_production_channel, :rollout_started],
        [:ios, :with_app_store, :with_production_channel, :review_failed],
        [:ios, :with_app_store, :with_phased_release, :submitted_for_review],
        [:ios, :with_app_store, :with_phased_release, :rollout_started],
        [:ios, :with_app_store, :with_phased_release, :review_failed]].each do |test_case|
        test_case_help = test_case.join(", ").humanize.downcase

        it "does not trigger step runs for the platform run #{test_case_help}" do
          platform = test_case.first
          deployment_traits = test_case[1..2]
          deployment_run_trait = test_case.last
          factory_tree = create_deployment_run_tree(platform,
            deployment_run_trait,
            deployment_traits:,
            step_traits: [:release],
            release_traits: [:with_no_platform_runs])
          release = factory_tree[:release]

          allow(Triggers::StepRun).to receive(:call)
          described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

          expect(Triggers::StepRun).not_to have_received(:call)
        end
      end
    end

    context "when hotfix release" do
      it "does not trigger step runs for the platform run for the first commit" do
        factory_tree = create_deployment_run_tree(:android, release_traits: [:hotfix])
        release = factory_tree[:release]
        _older_release = create(:release, :finished, train:, scheduled_at: 1.day.ago)

        allow(Triggers::StepRun).to receive(:call)
        described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

        expect(Triggers::StepRun).not_to have_received(:call)
      end

      it "does not trigger step runs for the platform run for subsequent commit" do
        factory_tree = create_deployment_run_tree(:android, :rollout_started, release_traits: [:hotfix])
        release = factory_tree[:release]
        _older_release = create(:release, :finished, train:, scheduled_at: 1.day.ago)
        allow(Triggers::StepRun).to receive(:call)
        described_class.process(release.reload, head_commit_attributes, rest_commit_attributes)

        expect(Triggers::StepRun).not_to have_received(:call)
      end
    end

    it "starts the release" do
      factory_tree = create_deployment_run_tree(:android, release_traits: [:with_no_platform_runs])
      release = factory_tree[:release]
      described_class.process(release, head_commit_attributes, rest_commit_attributes)

      expect(release.reload.on_track?).to be(true)
    end

    it "creates a new commit" do
      factory_tree = create_deployment_run_tree(:android, release_traits: [:with_no_platform_runs])
      release = factory_tree[:release]
      expect {
        described_class.process(release, head_commit_attributes, rest_commit_attributes)
      }.to change(Commit, :count)
    end

    it "creates multiple commits if present" do
      factory_tree = create_deployment_run_tree(:android, release_traits: [:with_no_platform_runs])
      release = factory_tree[:release]

      expect {
        described_class.process(release, head_commit_attributes, rest_commit_attributes)
      }.to change(Commit, :count).by(3)
    end

    it "creates only the head commit if none other" do
      factory_tree = create_deployment_run_tree(:android, release_traits: [:with_no_platform_runs])
      release = factory_tree[:release]

      expect {
        described_class.process(release, head_commit_attributes, [])
      }.to change(Commit, :count).by(1)
    end

    it "triggers step runs" do
      factory_tree = create_deployment_run_tree(:android, release_traits: [:with_no_platform_runs])
      release = factory_tree[:release]
      allow(Triggers::StepRun).to receive(:call)

      described_class.process(release, head_commit_attributes, rest_commit_attributes)

      expect(Triggers::StepRun).to have_received(:call).once
    end

    context "when build queue" do
      let(:queue_size) { 3 }
      let(:factory_tree) {
        create_deployment_tree(:android, step_traits: [:release], train_traits: [:with_build_queue])
      }
      let(:train) { factory_tree[:train] }
      let(:release) { create(:release, :created, train:) }

      before do
        train.update!(build_queue_size: queue_size)
      end

      it "triggers step run for the first commit" do
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, [])

        expect(Triggers::StepRun).to have_received(:call).once
      end

      it "adds the subsequent commits to the queue" do
        _old_commit = create(:commit, release:, timestamp: 1.minute.ago)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, [])

        expect(Triggers::StepRun).not_to have_received(:call)
        expect(release.applied_commits.reload.size).to be(1)
        expect(release.all_commits.reload.last.build_queue).to eql(release.active_build_queue)
      end

      it "adds all commits to the queue when multiple commits" do
        old_commit = create(:commit, release:)
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
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, rest_commit_attributes)

        expect(Triggers::StepRun).to have_received(:call).once
      end

      it "does not apply the build queue if head commit does not cross the queue size" do
        _old_commit = create(:commit, release:)
        allow(Triggers::StepRun).to receive(:call)

        described_class.process(release, head_commit_attributes, rest_commit_attributes.take(1))

        expect(Triggers::StepRun).not_to have_received(:call)
      end
    end
  end
end
