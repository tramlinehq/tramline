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
end
