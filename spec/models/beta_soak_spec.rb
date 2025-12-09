require "rails_helper"

describe BetaSoak do
  let(:release) { create(:release) }
  let(:beta_soak) { create(:beta_soak, release: release) }

  describe "#expired?" do
    it "disregards ended_at" do
      soak = create(:beta_soak, :ended, release: release)
      expect(soak.expired?).to be(false)
    end

    it "returns true when period has elapsed" do
      soak = create(:beta_soak, :completed_naturally, release: release)
      expect(soak.expired?).to be(true)
    end

    it "returns false when still active" do
      soak = create(:beta_soak, :active, release: release)
      expect(soak.expired?).to be(false)
    end
  end

  describe "#time_remaining" do
    it "returns 0 when expired" do
      soak = create(:beta_soak, :completed_naturally, release: release)
      expect(soak.time_remaining).to eq(0)
    end

    it "returns positive seconds when active" do
      soak = create(:beta_soak, :active, release: release)
      expect(soak.time_remaining).to be > 0
    end

    it "returns 0 when ended manually" do
      soak = create(:beta_soak, :ended, release: release)
      expect(soak.time_remaining).to eq(0)
    end
  end

  describe "#end_time" do
    it "returns calculated end time when started" do
      started_at = 2.hours.ago
      soak = create(:beta_soak, started_at: started_at, period_hours: 24, release: release)
      expected_end = started_at + 24.hours

      expect(soak.end_time).to be_within(1.second).of(expected_end)
    end
  end

  describe "associations" do
    it "belongs to release" do
      expect(beta_soak.release).to eq(release)
    end
  end

  describe "passportable" do
    it "includes Passportable concern" do
      expect(described_class.ancestors).to include(Passportable)
    end

    it "has correct stampable reasons" do
      expected_reasons = %w[
        beta_soak_started
        beta_soak_extended
        beta_soak_ended
      ]
      expect(BetaSoak::STAMPABLE_REASONS).to eq(expected_reasons)
    end

    it "has correct stamp namespace" do
      expect(beta_soak.stamp_namespace).to eq("beta_soak")
    end
  end
end
