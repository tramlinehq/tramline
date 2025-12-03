require "rails_helper"

describe LiveRelease::SoakComponent, type: :component do
  let(:app) { create(:app, :android, timezone: "America/New_York") }
  let(:train) { create(:train, app:, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }

  describe "#show_soak_actions?" do
    let(:component) { described_class.new(release) }

    it "returns true when beta soak is active" do
      create(:beta_soak, :active, release: release)
      expect(component.show_soak_actions?).to be(true)
    end

    it "returns false when no beta soak exists" do
      expect(component.show_soak_actions?).to be_nil
    end

    it "returns false when beta soak has completed" do
      create(:beta_soak, :ended, release: release)
      expect(component.show_soak_actions?).to be(false)
    end
  end

  describe "#time_remaining_hours" do
    let(:component) { described_class.new(release) }

    it "returns 0 when no beta soak exists" do
      expect(component.time_remaining_hours).to eq(0)
    end

    it "returns hours remaining when soak is active" do
      create(:beta_soak, :active, release: release)
      expect(component.time_remaining_hours).to be_within(0.1).of(23.0)
    end

    it "returns 0 when soak has completed" do
      create(:beta_soak, :ended, release: release)
      expect(component.time_remaining_hours).to eq(0)
    end

    it "calculates fractional hours correctly" do
      create(:beta_soak, started_at: 30.minutes.ago, period_hours: 24, release: release)
      expect(component.time_remaining_hours).to be_within(0.1).of(23.5)
    end
  end

  describe "#time_remaining" do
    let(:component) { described_class.new(release) }

    it "returns 00:00:00 when no beta soak exists" do
      expect(component.time_remaining).to eq("00:00:00")
    end

    it "formats time correctly for hours < 24" do
      create(:beta_soak, :active, release: release)
      expect(component.time_remaining).to match(/^2[23]:\d{2}:\d{2}$/)
    end

    it "formats time correctly for hours >= 24" do
      create(:beta_soak, :active, :with_custom_period, release: release)
      expect(component.time_remaining).to match(/^4[67]:\d{2}:\d{2}$/)
    end

    it "handles 168 hour (7 day) soak period" do
      create(:beta_soak, started_at: 1.hour.ago, period_hours: 168, release: release)
      display = component.time_remaining
      expect(display).to start_with("16")
    end

    it "returns 00:00:00 when soak has completed" do
      create(:beta_soak, :ended, release: release)
      expect(component.time_remaining).to eq("00:00:00")
    end

    it "pads hours, minutes, and seconds with zeros" do
      # Set soak to complete in roughly 9 hours, 5 minutes
      remaining_seconds = (9 * 3600) + (5 * 60)
      create(:beta_soak, started_at: Time.current - (24.hours - remaining_seconds), period_hours: 24, release: release)

      display = component.time_remaining
      expect(display).to match(/^09:0[45]:\d{2}$/)
    end
  end

  describe "#soak_start_time" do
    let(:component) { described_class.new(release) }

    it "returns nil when no beta soak exists" do
      expect(component.soak_start_time).to be_nil
    end

    it "formats time in app's timezone" do
      start_time = Time.parse("2025-01-15 12:00:00 UTC")
      create(:beta_soak, started_at: start_time, release: release)

      display = component.soak_start_time
      # In America/New_York, this would be 07:00 (EST, UTC-5)
      expect(display).to include("2025-01-15")
      expect(display).to include("EST").or include("EDT")
    end

    it "includes year, month, day, hour, minute, and timezone" do
      create(:beta_soak, :active, release: release)
      display = component.soak_start_time

      expect(display).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2} \w+/)
    end
  end

  describe "#soak_end_time" do
    let(:component) { described_class.new(release) }

    it "returns nil when no beta soak exists" do
      expect(component.soak_end_time).to be_nil
    end

    it "formats end time in app's timezone" do
      start_time = Time.parse("2025-01-15 12:00:00 UTC")
      create(:beta_soak, started_at: start_time, period_hours: 24, release: release)

      display = component.soak_end_time
      # End time should be 24 hours later
      expect(display).to include("2025-01-16")
      expect(display).to include("EST").or include("EDT")
    end

    it "calculates end time correctly with custom hours" do
      start_time = Time.parse("2025-01-15 12:00:00 UTC")
      create(:beta_soak, started_at: start_time, period_hours: 48, release: release)

      display = component.soak_end_time
      # End time should be 48 hours later
      expect(display).to include("2025-01-17")
    end
  end

  describe "integration with release" do
    let(:component) { described_class.new(release) }

    it "uses beta soak's time_remaining for calculations" do
      create(:beta_soak, :active, release: release)

      expect(component.time_remaining_hours).to be > 0
      expect(component.time_remaining).not_to eq("00:00:00")
    end
  end

  describe "nil safety" do
    let(:component) { described_class.new(release) }

    it "handles nil beta_soak gracefully" do
      expect(component.time_remaining_hours).to eq(0)
      expect(component.time_remaining).to eq("00:00:00")
    end
  end
end
