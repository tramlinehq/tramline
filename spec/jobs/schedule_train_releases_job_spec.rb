require "rails_helper"

# rubocop:disable Rails/DurationArithmetic
describe ScheduleTrainReleasesJob do
  it "schedules release for active trains" do
    train = create(:train, :active, :with_schedule)
    train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

    travel_to train.kickoff_at + 1.hour do
      described_class.new.perform
      expect(train.reload.scheduled_releases.count).to eq(2)
      expect(train.reload.scheduled_releases.last.scheduled_at).to eq(train.kickoff_at + train.repeat_duration)
    end
  end

  it "does not schedule release for inactive trains" do
    train = create(:train, :inactive, :with_schedule)
    expect(train.scheduled_releases.count).to eq(0)

    described_class.new.perform

    expect(train.reload.scheduled_releases.count).to eq(0)
  end

  it "does not schedule release for active trains with nothing to schedule" do
    train = create(:train, :with_almost_trunk, :active, kickoff_at: Time.current + 2.hours, repeat_duration: 5.days)
    train.scheduled_releases.create!(scheduled_at: train.kickoff_at)

    expect(train.scheduled_releases.count).to eq(1)

    described_class.new.perform

    expect(train.reload.scheduled_releases.count).to eq(1)
  end
end
# rubocop:enable Rails/DurationArithmetic
