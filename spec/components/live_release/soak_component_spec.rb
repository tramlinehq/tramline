require "rails_helper"

describe LiveRelease::SoakComponent, type: :component do
  let(:app) { create(:app, :android, timezone: "America/New_York") }
  let(:train) { create(:train, app:, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_pilot) { release.train.app.organization.owner }
  let(:other_user) { create(:user, :as_developer, member_organization: release.train.app.organization) }

  describe "#show_soak_actions?" do
    context "when user is release pilot" do
      let(:component) { described_class.new(release, release_pilot) }

      it "returns true when soak is active" do
        release.update!(soak_started_at: 1.hour.ago)
        expect(component.show_soak_actions?).to eq(true)
      end

      it "returns false when soak is not active" do
        expect(component.show_soak_actions?).to eq(false)
      end

      it "returns false when soak has completed" do
        release.update!(soak_started_at: 25.hours.ago)
        expect(component.show_soak_actions?).to eq(false)
      end
    end

    context "when user is not release pilot" do
      let(:component) { described_class.new(release, other_user) }

      it "returns false even when soak is active" do
        release.update!(soak_started_at: 1.hour.ago)
        expect(component.show_soak_actions?).to eq(false)
      end
    end

    context "when user is nil" do
      let(:component) { described_class.new(release, nil) }

      it "returns false" do
        release.update!(soak_started_at: 1.hour.ago)
        expect(component.show_soak_actions?).to eq(false)
      end
    end
  end

  describe "#show_pilot_only_message?" do
    let(:component) { described_class.new(release, other_user) }

    it "returns true when soak is active and user is not release pilot" do
      release.update!(soak_started_at: 1.hour.ago)
      expect(component.show_pilot_only_message?).to eq(true)
    end

    it "returns false when soak is not active" do
      expect(component.show_pilot_only_message?).to eq(false)
    end

    context "when user is release pilot" do
      let(:component) { described_class.new(release, release_pilot) }

      it "returns false" do
        release.update!(soak_started_at: 1.hour.ago)
        expect(component.show_pilot_only_message?).to eq(false)
      end
    end
  end

  describe "#user_is_release_pilot?" do
    it "returns true when user is the release pilot" do
      component = described_class.new(release, release_pilot)
      expect(component.send(:user_is_release_pilot?)).to eq(true)
    end

    it "returns false when user is not the release pilot" do
      component = described_class.new(release, other_user)
      expect(component.send(:user_is_release_pilot?)).to eq(false)
    end

    it "returns false when user is nil" do
      component = described_class.new(release, nil)
      expect(component.send(:user_is_release_pilot?)).to eq(false)
    end
  end

  describe "#time_remaining_hours" do
    let(:component) { described_class.new(release, release_pilot) }

    it "returns 0 when soak has not started" do
      expect(component.time_remaining_hours).to eq(0)
    end

    it "returns hours remaining when soak is active" do
      release.update!(soak_started_at: 1.hour.ago)
      expect(component.time_remaining_hours).to be_within(0.1).of(23.0)
    end

    it "returns 0 when soak has completed" do
      release.update!(soak_started_at: 25.hours.ago)
      expect(component.time_remaining_hours).to eq(0)
    end

    it "calculates fractional hours correctly" do
      release.update!(soak_started_at: 30.minutes.ago)
      expect(component.time_remaining_hours).to be_within(0.1).of(23.5)
    end
  end

  describe "#time_remaining_display" do
    let(:component) { described_class.new(release, release_pilot) }

    it "returns 00:00:00 when soak has not started" do
      expect(component.time_remaining_display).to eq("00:00:00")
    end

    it "formats time correctly for hours < 24" do
      release.update!(soak_started_at: 1.hour.ago)
      expect(component.time_remaining_display).to match(/^23:\d{2}:\d{2}$/)
    end

    it "formats time correctly for hours >= 24" do
      release.train.update!(soak_period_hours: 48)
      release.update!(soak_started_at: 1.hour.ago)
      expect(component.time_remaining_display).to match(/^47:\d{2}:\d{2}$/)
    end

    it "handles 168 hour (7 day) soak period" do
      release.train.update!(soak_period_hours: 168)
      release.update!(soak_started_at: 1.hour.ago)
      display = component.time_remaining_display
      expect(display).to start_with("167:")
    end

    it "returns 00:00:00 when soak has completed" do
      release.update!(soak_started_at: 25.hours.ago)
      expect(component.time_remaining_display).to eq("00:00:00")
    end

    it "pads hours, minutes, and seconds with zeros" do
      # Set soak to complete in exactly 9 hours, 5 minutes, 3 seconds
      remaining_seconds = (9 * 3600) + (5 * 60) + 3
      release.update!(soak_started_at: Time.current - (24.hours - remaining_seconds))

      display = component.time_remaining_display
      expect(display).to match(/^\d{2}:05:03$/)
    end
  end

  describe "#soak_start_time_display" do
    let(:component) { described_class.new(release, release_pilot) }

    it "returns nil when soak has not started" do
      expect(component.soak_start_time_display).to be_nil
    end

    it "formats time in app's timezone" do
      start_time = Time.parse("2025-01-15 12:00:00 UTC")
      release.update!(soak_started_at: start_time)

      display = component.soak_start_time_display
      # In America/New_York, this would be 07:00 (EST, UTC-5)
      expect(display).to include("2025-01-15")
      expect(display).to include("EST").or include("EDT")
    end

    it "includes year, month, day, hour, minute, and timezone" do
      release.update!(soak_started_at: Time.current)
      display = component.soak_start_time_display

      expect(display).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2} \w+/)
    end
  end

  describe "#soak_end_time_display" do
    let(:component) { described_class.new(release, release_pilot) }

    it "returns nil when soak has not started" do
      expect(component.soak_end_time_display).to be_nil
    end

    it "formats end time in app's timezone" do
      start_time = Time.parse("2025-01-15 12:00:00 UTC")
      release.update!(soak_started_at: start_time)

      display = component.soak_end_time_display
      # End time should be 24 hours later
      expect(display).to include("2025-01-16")
      expect(display).to include("EST").or include("EDT")
    end

    it "calculates end time correctly with custom hours" do
      start_time = Time.parse("2025-01-15 12:00:00 UTC")
      release.train.update!(soak_period_hours: 48)
      release.update!(soak_started_at: start_time)

      display = component.soak_end_time_display
      # End time should be 48 hours later
      expect(display).to include("2025-01-17")
    end
  end

  describe "integration with release" do
    let(:component) { described_class.new(release, release_pilot) }

    it "delegates soak_period_enabled? to release" do
      expect(component.instance_variable_get(:@release)).to receive(:soak_period_enabled?).and_return(true)
      component.instance_variable_get(:@release).soak_period_enabled?
    end

    it "uses release's soak_time_remaining for calculations" do
      release.update!(soak_started_at: 2.hours.ago)

      expect(component.time_remaining_hours).to be > 0
      expect(component.time_remaining_display).not_to eq("00:00:00")
    end
  end

  describe "nil safety" do
    let(:component) { described_class.new(release, release_pilot) }

    it "handles nil soak_time_remaining gracefully" do
      allow(release).to receive(:soak_time_remaining).and_return(nil)

      expect(component.time_remaining_hours).to eq(0)
      expect(component.time_remaining_display).to eq("00:00:00")
    end
  end
end
