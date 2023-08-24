require "rails_helper"

describe BuildQueue do
  it "has valid factory" do
    expect(create(:build_queue)).to be_valid
  end

  describe "#add_commit!" do
    it "adds commit to the build queue" do
      train = create(:train, :with_build_queue)
      release = create(:release, train:)
      commit = create(:commit, release:)
      build_queue = release.active_build_queue

      build_queue.add_commit!(commit)

      expect(build_queue.commits).to include(commit)
    end

    it "applies the build queue when build queue has more commits than its size" do
      allow(Triggers::StepRun).to receive(:call)

      queue_size = 2
      train = create(:train, :with_build_queue, build_queue_size: queue_size)
      release_platform = create(:release_platform, train:)
      step = create(:step, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      commits = create_list(:commit, queue_size, release:)
      build_queue = release.active_build_queue

      commits.each do |commit|
        build_queue.add_commit!(commit)
      end

      expect(Triggers::StepRun).to have_received(:call).with(step, commits.last, release_platform_run).once
    end

    it "does not apply the build queue when build queue has less commits than its size" do
      allow(Triggers::StepRun).to receive(:call)

      queue_size = 2
      train = create(:train, :with_build_queue, build_queue_size: queue_size)
      release_platform = create(:release_platform, train:)
      create(:step, :with_deployment, release_platform:)
      release = create(:release, train:)
      create(:release_platform_run, release_platform:, release:)
      commit = create(:commit, release:)
      build_queue = release.active_build_queue

      build_queue.add_commit!(commit)

      expect(Triggers::StepRun).not_to have_received(:call)
    end
  end

  describe "#apply!" do
    it "triggers the step run for the head commit of the build queue" do
      allow(Triggers::StepRun).to receive(:call)

      train = create(:train, :with_build_queue)
      release_platform = create(:release_platform, train:)
      step = create(:step, :with_deployment, release_platform:)
      release = create(:release, train:)
      release_platform_run = create(:release_platform_run, release_platform:, release:)
      build_queue = release.active_build_queue
      create_list(:commit, 5, release:, build_queue:, timestamp: 3.hours.ago)
      head_commit = create(:commit, release:, build_queue:, timestamp: 2.hours.ago)
      allow(release).to receive(:latest_commit_hash).and_return(head_commit.commit_hash)

      build_queue.apply!

      expect(Triggers::StepRun).to have_received(:call).with(step, head_commit, release_platform_run).once
    end

    it "does not trigger step runs if it has no commits" do
      allow(Triggers::StepRun).to receive(:call)

      queue_size = 2
      train = create(:train, :with_build_queue, build_queue_size: queue_size)
      release_platform = create(:release_platform, train:)
      create(:step, :with_deployment, release_platform:)
      release = create(:release, train:)
      create(:release_platform_run, release_platform:, release:)

      release.active_build_queue.apply!

      expect(Triggers::StepRun).not_to have_received(:call)
    end

    it "marks the build queue as inactive" do
      allow(Triggers::StepRun).to receive(:call)

      train = create(:train, :with_build_queue)
      release_platform = create(:release_platform, train:)
      create(:step, :with_deployment, release_platform:)
      release = create(:release, train:)
      create(:release_platform_run, release_platform:, release:)
      build_queue = release.active_build_queue
      create_list(:commit, 5, release:, build_queue:, timestamp: 3.hours.ago)
      head_commit = create(:commit, release:, build_queue:, timestamp: 2.hours.ago)
      allow(release).to receive(:latest_commit_hash).and_return(head_commit.commit_hash)

      freeze_time do
        build_queue.apply!

        expect(build_queue.reload.is_active?).to be(false)
        expect(build_queue.reload.applied_at).to eql(Time.current)
      end
    end

    it "creates a new active build queue" do
      allow(Triggers::StepRun).to receive(:call)

      train = create(:train, :with_build_queue)
      release_platform = create(:release_platform, train:)
      create(:step, :with_deployment, release_platform:)
      release = create(:release, train:)
      create(:release_platform_run, release_platform:, release:)
      build_queue = release.active_build_queue
      create_list(:commit, 5, release:, build_queue:, timestamp: 3.hours.ago)
      head_commit = create(:commit, release:, build_queue:, timestamp: 2.hours.ago)
      allow(release).to receive(:latest_commit_hash).and_return(head_commit.commit_hash)

      build_queue.apply!

      expect(release.active_build_queue.reload).not_to be_nil
      expect(release.build_queues.size).to be(2)
      expect(release.reload.active_build_queue.id).not_to be(build_queue.id)
    end
  end
end
