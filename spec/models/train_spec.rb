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
end
