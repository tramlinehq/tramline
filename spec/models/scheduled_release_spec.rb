# frozen_string_literal: true

require "rails_helper"

describe ScheduledRelease do
  let(:train) { create(:train, :active) }

  describe "#manually_skip" do
    it "marks the release as manually_skipped" do
      scheduled_at = Time.current

      travel_to scheduled_at - 1.hour do
        scheduled_release = create(:scheduled_release, train:, scheduled_at:, manually_skipped: false)

        scheduled_release.manually_skip

        expect(scheduled_release.manually_skipped?).to be true
      end
    end

    it "does not mark the release as manually_skipped if its schedule time is in the past" do
      scheduled_at = Time.current

      travel_to scheduled_at + 1.hour do
        scheduled_release = create(:scheduled_release, train:, scheduled_at:, manually_skipped: false)

        scheduled_release.manually_skip

        expect(scheduled_release.manually_skipped?).to be false
      end
    end
  end

  describe "#manually_resume" do
    it "marks manually_skipped to be false" do
      scheduled_at = Time.current

      travel_to scheduled_at - 1.hour do
        scheduled_release = create(:scheduled_release, train:, scheduled_at:, manually_skipped: true)

        scheduled_release.manually_resume

        expect(scheduled_release.manually_skipped?).to be false
      end
    end

    it "does not modify the manually_skipped setting if its schedule time is in the past" do
      scheduled_at = Time.current

      travel_to scheduled_at + 1.hour do
        scheduled_release = create(:scheduled_release, scheduled_at:, manually_skipped: true)

        scheduled_release.manually_resume

        expect(scheduled_release.manually_skipped?).to be true
      end
    end
  end

  describe ".past" do
    let(:train) { create(:train, :active) }
    let(:base_time) { Time.current }
    let!(:oldest) { create(:scheduled_release, train: train, scheduled_at: base_time - 4.hours) }
    let!(:discarded) { create(:scheduled_release, train: train, scheduled_at: base_time - 3.hours) }
    let!(:earlier) { create(:scheduled_release, train: train, scheduled_at: base_time - 2.hours) }
    let!(:recent) { create(:scheduled_release, train: train, scheduled_at: base_time - 1.hour) }

    before do
      discarded.discard!
    end

    context "with default parameters" do
      it "returns the last 2 scheduled releases before the given time, including discarded ones" do
        result = train.scheduled_releases.past(2, before: base_time)

        expect(result).to contain_exactly(earlier, recent)
        expect(result.first).to eq(earlier)
        expect(result.last).to eq(recent)
      end
    end

    context "with custom n parameter" do
      it "returns the specified number of past releases" do
        result = train.scheduled_releases.past(3, before: base_time)

        expect(result.size).to eq(3)
        expect(result).to contain_exactly(discarded, earlier, recent)
      end

      it "returns all available releases when n exceeds count" do
        result = train.scheduled_releases.past(10, before: base_time)

        expect(result.size).to eq(4)
        expect(result).to contain_exactly(oldest, discarded, earlier, recent)
      end

      it "returns empty array when n is 0" do
        result = train.scheduled_releases.past(0, before: base_time)

        expect(result).to be_empty
      end
    end

    context "when include_discarded is false" do
      it "excludes discarded scheduled releases" do
        result = train.scheduled_releases.past(3, before: base_time, include_discarded: false)

        expect(result).to contain_exactly(oldest, earlier, recent)
        expect(result).not_to include(discarded)
      end

      it "returns correct count when some releases are discarded" do
        earlier.discard!

        result = train.scheduled_releases.past(3, before: base_time, include_discarded: false)

        expect(result.size).to eq(2)
        expect(result).to contain_exactly(oldest, recent)
      end
    end

    context "with different before times" do
      it "only includes releases before the specified time" do
        cutoff_time = base_time - 1.5.hours

        result = train.scheduled_releases.past(5, before: cutoff_time)

        expect(result).to contain_exactly(oldest, discarded, earlier)
        expect(result).not_to include(recent)
      end

      it "returns empty array when before time is before all scheduled releases" do
        very_early_time = base_time - 5.hours

        result = train.scheduled_releases.past(5, before: very_early_time)

        expect(result).to be_empty
      end
    end

    context "with ordering" do
      it "returns results ordered by scheduled_at ascending" do
        result = train.scheduled_releases.past(4, before: base_time)

        expect(result.map(&:scheduled_at)).to eq([
          oldest.scheduled_at,
          discarded.scheduled_at,
          earlier.scheduled_at,
          recent.scheduled_at
        ])
      end
    end

    context "with edge cases" do
      it "handles exact time match correctly" do
        exact_time_release = create(:scheduled_release, train: train, scheduled_at: base_time)

        result = train.scheduled_releases.past(5, before: base_time)

        expect(result).not_to include(exact_time_release)
      end
    end
  end

  describe ".future" do
    let(:train) { create(:train, :active) }
    let(:base_time) { Time.current }
    let!(:past) { create(:scheduled_release, train: train, scheduled_at: base_time - 1.hour) }
    let!(:future_next) { create(:scheduled_release, train: train, scheduled_at: base_time + 1.hour) }
    let!(:future_later) { create(:scheduled_release, train: train, scheduled_at: base_time + 2.hours) }
    let!(:future_much_later) { create(:scheduled_release, train: train, scheduled_at: base_time + 3.hours) }

    before do
      future_later.discard!
    end

    context "with default parameters" do
      it "returns the next scheduled release after current time, excluding discarded ones" do
        result = train.scheduled_releases.future

        expect(result.size).to eq(1)
        expect(result.first).to eq(future_next)
        expect(result).not_to include(future_later)
      end
    end

    context "with custom n parameter" do
      it "returns the specified number of future releases" do
        result = train.scheduled_releases.future(2)

        expect(result.size).to eq(2)
        expect(result).to contain_exactly(future_next, future_much_later)
      end

      it "returns all available future releases when n exceeds count" do
        result = train.scheduled_releases.future(10)

        expect(result.size).to eq(2)
        expect(result).to contain_exactly(future_next, future_much_later)
      end

      it "returns empty array when n is 0" do
        result = train.scheduled_releases.future(0)

        expect(result).to be_empty
      end
    end

    context "with ordering" do
      it "returns results ordered by scheduled_at ascending" do
        result = train.scheduled_releases.future(2)

        expect(result.map(&:scheduled_at)).to eq([
          future_next.scheduled_at,
          future_much_later.scheduled_at
        ])
      end
    end

    context "with edge cases" do
      it "does not include past releases" do
        result = train.scheduled_releases.future(10)

        expect(result).not_to include(past)
      end

      it "automatically excludes discarded releases" do
        result = train.scheduled_releases.future(10)

        expect(result).not_to include(future_later)
      end
    end

    context "when comparing with pending scope" do
      it "behaves identically to pending scope with ordering and limit" do
        pending_result = train.scheduled_releases.pending.order(scheduled_at: :asc).limit(2)
        future_result = train.scheduled_releases.future(2)

        expect(future_result.to_a).to eq(pending_result.to_a)
      end

      it "returns first future release same as pending" do
        pending_result = train.scheduled_releases.pending.order(scheduled_at: :asc).first
        future_result = train.scheduled_releases.future(1).first

        expect(future_result).to eq(pending_result)
      end
    end
  end
end
