require "rails_helper"

# rubocop:disable Rails/DurationArithmetic
describe ScheduleTrainReleasesJob do
  it "schedules release for active trains" do
    train = create(:train, :active, :with_schedule)
    tz = train.app.timezone

    # Create a scheduled release in the past
    first_scheduled = 2.hours.ago.in_time_zone(tz).change(hour: 14, min: 0, sec: 0).utc
    train.scheduled_releases.create!(scheduled_at: first_scheduled)

    travel_to first_scheduled + 1.hour do
      described_class.new.perform
      expect(train.reload.scheduled_releases.count).to eq(2)
      expect(train.reload.scheduled_releases.last.scheduled_at).to eq(first_scheduled + train.repeat_duration)
    end
  end

  it "does not schedule release for inactive trains" do
    train = create(:train, :inactive, :with_schedule)
    expect(train.scheduled_releases.count).to eq(0)

    described_class.new.perform

    expect(train.reload.scheduled_releases.count).to eq(0)
  end

  it "does not schedule release for active trains with nothing to schedule" do
    future_time = (Time.current + 2.hours).strftime("%H:%M:%S")
    train = create(:train, :with_almost_trunk, :active, kickoff_time: future_time, repeat_duration: 5.days)
    tz = train.app.timezone

    # Create a scheduled release in the future
    future_scheduled = Time.current.in_time_zone(tz).change(hour: Time.current.hour + 2).utc
    train.scheduled_releases.create!(scheduled_at: future_scheduled)

    expect(train.scheduled_releases.count).to eq(1)

    described_class.new.perform

    expect(train.reload.scheduled_releases.count).to eq(1)
  end
end
# rubocop:enable Rails/DurationArithmetic
