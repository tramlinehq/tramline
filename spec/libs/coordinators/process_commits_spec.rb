# frozen_string_literal: true

require "rails_helper"

describe Coordinators::ProcessCommits do
  let(:head_commit_hash) { SecureRandom.uuid.split("-").join }
  let(:head_commit_attributes) do
    {
      commit_hash: head_commit_hash,
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

  describe "#call" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }

    context "when production submission has happened" do
      it "continues to trigger builds" do
        create_production_rollout_tree(
          train,
          release_platform,
          release_traits: [:on_track],
          run_status: :on_track,
          rollout_status: :created,
          skip_rollout: false
        ) => {release:}
        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, rest_commit_attributes)

        expect(Coordinators::CreateBetaRelease).to have_received(:call)
      end
    end

    context "when hotfix release" do
      it "does not trigger any submissions for the first commit" do
        older_release = create(:release, :finished, train:, scheduled_at: 1.day.ago)
        _last_old_commit = create(:commit, commit_hash: head_commit_hash, release: older_release)
        create_production_rollout_tree(
          train,
          release_platform,
          release_traits: [:on_track, :hotfix],
          run_status: :on_track,
          rollout_status: :created,
          skip_rollout: false
        ) => {release:}
        release.hotfixed_from = older_release
        release.save!

        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, rest_commit_attributes)

        expect(Coordinators::CreateBetaRelease).not_to have_received(:call)
      end

      it "triggers only when there's a new hotfix commit" do
        older_release = create(:release, :finished, train:, scheduled_at: 1.day.ago)
        _last_old_commit = create(:commit, release: older_release)
        create_production_rollout_tree(
          train,
          release_platform,
          release_traits: [:on_track, :hotfix],
          run_status: :on_track,
          rollout_status: :created,
          skip_rollout: false
        ) => {release:}
        release.hotfixed_from = older_release
        release.save!

        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, rest_commit_attributes)

        expect(Coordinators::CreateBetaRelease).to have_received(:call)
      end
    end

    it "starts the release" do
      release = create(:release, :created, :with_no_platform_runs, train:)
      _release_platform_run = create(:release_platform_run, release_platform:, release:)

      described_class.call(release, head_commit_attributes, rest_commit_attributes)

      expect(release.reload.on_track?).to be(true)
    end

    it "creates a new commit" do
      release = create(:release, :created, :with_no_platform_runs, train:)
      _release_platform_run = create(:release_platform_run, release_platform:, release:)

      expect {
        described_class.call(release, head_commit_attributes, [])
      }.to change(Commit, :count).by(1)
    end

    it "creates multiple commits if present" do
      release = create(:release, :created, :with_no_platform_runs, train:)
      _release_platform_run = create(:release_platform_run, release_platform:, release:)

      expect {
        described_class.call(release, head_commit_attributes, rest_commit_attributes)
      }.to change(Commit, :count).by(3)
    end

    it "triggers builds" do
      release = create(:release, :created, :with_no_platform_runs, train:)
      _release_platform_run = create(:release_platform_run, release_platform:, release:)
      allow(Coordinators::CreateBetaRelease).to receive(:call)

      described_class.call(release, head_commit_attributes, rest_commit_attributes)

      expect(Coordinators::CreateBetaRelease).to have_received(:call)
    end

    context "when build queue" do
      let(:queue_size) { 3 }
      let(:train) { create(:train, :with_build_queue) }
      let(:release_platform) { create(:release_platform, train:) }
      let(:release) { create(:release, :created, :with_no_platform_runs, train:) }

      before do
        create(:release_platform_run, release_platform:, release:)
        train.update!(build_queue_size: queue_size)
      end

      it "triggers build for the first commit" do
        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, [])

        expect(Coordinators::CreateBetaRelease).to have_received(:call).once
      end

      it "adds the subsequent commits to the queue" do
        _old_commit = create(:commit, release:, timestamp: 1.hour.ago)
        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, [])

        expect(Coordinators::CreateBetaRelease).not_to have_received(:call)
        expect(release.applied_commits.reload.size).to be(1)
        expect(release.all_commits.reload.last.build_queue).to eql(release.active_build_queue)
      end

      it "adds all commits to the queue when multiple commits" do
        old_commit = create(:commit, release:)
        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, rest_commit_attributes.take(1))

        expect(release.applied_commits.reload.size).to be(1)
        expect(release.all_commits.reload.size).to be(3)
        release.all_commits.where.not(id: old_commit.id).find_each do |c|
          expect(c.build_queue).to eq(release.active_build_queue)
        end
      end

      it "applies the build queue if head commit crosses the queue size" do
        _old_commit = create(:commit, release:)
        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, rest_commit_attributes)

        expect(Coordinators::CreateBetaRelease).to have_received(:call).once
      end

      it "does not apply the build queue if head commit does not cross the queue size" do
        _old_commit = create(:commit, release:)
        allow(Coordinators::CreateBetaRelease).to receive(:call)

        described_class.call(release, head_commit_attributes, rest_commit_attributes.take(1))

        expect(Coordinators::CreateBetaRelease).not_to have_received(:call)
      end
    end

    context "when fudging head commit timestamp" do
      it "adds 1 millisecond" do
        release = create(:release, :created, :with_no_platform_runs, train:)
        _release_platform_run = create(:release_platform_run, release_platform:, release:)

        t = Time.current
        t_minus_ms = Time.new(t.year, t.month, t.day, t.hour, t.min, t.sec, t.utc_offset)

        commit_attributes = {
          commit_hash: head_commit_hash,
          message: Faker::Lorem.sentence,
          timestamp: t_minus_ms,
          author_name: Faker::Name.name,
          author_email: Faker::Internet.email,
          url: Faker::Internet.url,
          branch_name: Faker::Lorem.word
        }

        described_class.call(release, commit_attributes, [])
        release.reload

        commit_ts = release.last_commit.timestamp
        fudged = ((commit_ts - t_minus_ms) * 1000).round
        expect(fudged).to eq(1)
      end

      it "ensures the commit order is maintained" do
        release = create(:release, :created, :with_no_platform_runs, train:)
        _release_platform_run = create(:release_platform_run, release_platform:, release:)

        t = Time.current
        t_minus_ms = Time.new(t.year, t.month, t.day, t.hour, t.min, t.sec, t.utc_offset)

        commit_attributes = {
          commit_hash: "1",
          message: Faker::Lorem.sentence,
          timestamp: t_minus_ms,
          author_name: Faker::Name.name,
          author_email: Faker::Internet.email,
          url: Faker::Internet.url,
          branch_name: Faker::Lorem.word
        }

        other_commit_attributes = [
          {
            commit_hash: "3",
            message: Faker::Lorem.sentence,
            timestamp: t_minus_ms,
            author_name: Faker::Name.name,
            author_email: Faker::Internet.email,
            url: Faker::Internet.url,
            branch_name: Faker::Lorem.word
          },
          {
            commit_hash: "2",
            message: Faker::Lorem.sentence,
            timestamp: t_minus_ms,
            author_name: Faker::Name.name,
            author_email: Faker::Internet.email,
            url: Faker::Internet.url,
            branch_name: Faker::Lorem.word
          }
        ]

        described_class.call(release, commit_attributes, other_commit_attributes)
        release.reload

        expect(release.all_commits.sequential.first.commit_hash).to eq("1")
      end
    end
  end
end
