require "rails_helper"

describe Train do
  it "has a valid factory" do
    expect(create(:train)).to be_valid
  end

  describe "#set_current_version" do
    it "sets it to the version_seeded_with" do
      ver = "1.2.3"
      train = build(:train, version_seeded_with: ver)

      expect(train.version_current).to be_nil
      train.save!
      expect(train.version_current).to eq(ver)
    end
  end

  describe "#create_release_platforms" do
    it "creates a release platform with android for android app" do
      app = create(:app, :android)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(1)
      expect(train.reload.release_platforms.first.platform).to eq(app.platform)
    end

    it "creates a release platform with ios for ios app" do
      app = create(:app, :ios)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(1)
      expect(train.reload.release_platforms.first.platform).to eq(app.platform)
    end

    it "creates a release platform per platform for cross-platform app" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)

      expect(train.reload.release_platforms.size).to eq(2)
      expect(train.reload.release_platforms.pluck(:platform)).to contain_exactly(*ReleasePlatform.platforms.keys)
    end
  end

  describe "#activate!" do
    it "marks the train as active" do
      train = create(:train, :draft)
      train.activate!

      expect(train.reload.active?).to be(true)
    end

    it "marks an inactive train as active" do
      train = create(:train, :inactive)
      train.activate!

      expect(train.reload.active?).to be(true)
    end

    it "schedules the release for an automatic train" do
      train = create(:train, :with_schedule, :draft)
      train.activate!

      expect(train.reload.scheduled_releases.count).to be(1)
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(train.kickoff_at)
    end
  end

  describe "#next_run_at" do
    it "returns kickoff time if no releases have been scheduled yet and kickoff is in the future" do
      train = create(:train, :with_schedule, :active)

      expect(train.next_run_at).to eq(train.kickoff_at)
    end

    it "returns kickoff + repeat duration time if no releases have been scheduled yet and kickoff is in the past" do
      train = create(:train, :with_schedule, :active)

      travel_to train.kickoff_at + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration)
      end
    end

    it "returns next available schedule time if there is a scheduled release" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

      travel_to train.kickoff_at + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration)
      end
    end

    it "returns next available schedule time if there are many scheduled releases" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at + train.repeat_duration)

      travel_to train.kickoff_at + 1.day + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration * 2)
      end
    end

    it "returns next available schedule time if there are scheduled releases and more than repeat duration has passed since last scheduled release" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

      travel_to train.kickoff_at + 2.days + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration * 3)
      end
    end
  end

  describe "#deactivate" do
    it "deletes the pending scheduled releases for an automatic train" do
      train = create(:train, :with_schedule, :draft)
      train.activate!
      expect(train.scheduled_releases.count).to be(1)

      train.deactivate!

      expect(train.reload.scheduled_releases.count).to be(0)
    end

    it "marks the train as inactive" do
      train = create(:train, :active)

      train.deactivate!

      expect(train.reload.inactive?).to be(true)
    end
  end

  describe "#update" do
    it "schedules the release for an automatic train" do
      train = create(:train, :with_almost_trunk, :active)
      expect(train.scheduled_releases.count).to be(0)

      train.update!(kickoff_at: 2.days.from_now, repeat_duration: 2.days)

      expect(train.reload.scheduled_releases.count).to be(1)
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(train.kickoff_at)
    end
  end

  describe "#hotfix_from" do
    let(:train) { create(:train, :with_almost_trunk, :active) }
    let(:release) { create(:release, :with_no_platform_runs, train:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_platform_run) { create(:release_platform_run, release:, release_platform:) }

    it "returns the last finished release" do
      create(:release, :finished, :with_no_platform_runs, train:, completed_at: 2.hours.ago)
      latest_release = create(:release, :finished, :with_no_platform_runs, train:, completed_at: Time.current)

      expect(train.hotfix_from).to eq(latest_release)
    end

    it "returns nothing if no finished releases" do
      expect(train.hotfix_from).to be_nil
    end
  end

  describe "#release_branch_name_fmt" do
    it "adds hotfix to branch name if hotfix" do
      train = create(:train, :with_almost_trunk, :active)

      expect(train.release_branch_name_fmt(hotfix: true)).to eq("hotfix/train/%Y-%m-%d")
    end
  end

  describe "#hotfixable?" do
    let(:factory_tree) {
      create_deployment_tree(:android,
        :with_production_channel,
        step_traits: [:release],
        train_traits: [:with_almost_trunk, :active])
    }
    let(:train) { factory_tree[:train] }
    let(:release_platform) { factory_tree[:release_platform] }
    let(:step) { factory_tree[:step] }
    let(:deployment) { factory_tree[:deployment] }
    let(:release) { create(:release, :finished, :with_no_platform_runs, train:) }

    before do
      _finished_release_run = create(:release_platform_run, release:, release_platform:)
    end

    it "is false if there is already another hotfix in progress" do
      hotfix_release = create(:release, :hotfix, :with_no_platform_runs, train:, hotfixed_from: release)
      create(:release_platform_run, release: hotfix_release, release_platform: create(:release_platform, train:))

      expect(train.reload.hotfixable?).to be(false)
    end

    it "is false if there is an ongoing release in progress" do
      ongoing_release = create(:release, :on_track, :with_no_platform_runs, train:, hotfixed_from: release)
      release_platform_run = create(:release_platform_run, release: ongoing_release, release_platform:)
      _step_run = create(:step_run, :deployment_started, step: step, release_platform_run:)

      expect(train.reload.hotfixable?).to be(false)
    end

    it "is true when a production train with a release to hotfix is available" do
      expect(train.reload.hotfixable?).to be(true)
    end
  end
end
