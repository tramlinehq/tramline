require "rails_helper"

describe Train do
  it "has a valid factory" do
    expect(create(:train)).to be_valid
  end

  describe "#bump_fix!" do
    it "updates the minor version if the current version is a partial semver" do
      train = create(:train, version_seeded_with: "1.2")
      _run = create(:release, train:)

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.4")
    end

    it "updates the patch version if the current version is a proper semver" do
      train = create(:train, version_seeded_with: "1.2.1")
      _run = create(:release, train:)

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.3.1")
    end

    it "does not do anything if there are no runs" do
      train = create(:train, version_seeded_with: "1.2.1")

      train.bump_fix!
      train.reload

      expect(train.version_current).to eq("1.3.0")
    end
  end

  describe "#bump_release!" do
    it "updates the minor version" do
      train = create(:train, version_seeded_with: "1.2.1")
      _run = create(:release, train:)

      train.bump_release!
      train.reload

      expect(train.version_current).to eq("1.4.0")
    end

    it "updates the major version if a greater major version is specified" do
      train = create(:train, version_seeded_with: "1.2.1")
      _run = create(:release, train:)

      train.bump_release!(true)
      train.reload

      expect(train.version_current).to eq("2.0.0")
    end

    it "does not do anything if there are no runs" do
      train = create(:train, version_seeded_with: "1.2.1")

      train.bump_release!
      train.reload

      expect(train.version_current).to eq("1.3.0")
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
      kickoff_at = 2.hours.from_now
      train = create(:train, :with_almost_trunk, :draft, kickoff_at:, repeat_duration: 1.day)
      train.activate!

      expect(train.reload.scheduled_releases.count).to be(1)
      expect(train.reload.scheduled_releases.first.scheduled_at).to eq(kickoff_at)
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

    it "returns next available schedule time if there are scheduled releases" do
      train = create(:train, :with_schedule, :active)
      train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

      travel_to train.kickoff_at + 1.hour do
        expect(train.next_run_at).to eq(train.kickoff_at + train.repeat_duration)
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
end
