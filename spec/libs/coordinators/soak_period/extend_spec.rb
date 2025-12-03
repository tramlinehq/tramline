# frozen_string_literal: true

require "rails_helper"

describe Coordinators::SoakPeriod::Extend do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:user) { create(:user) }
  let(:additional_hours) { 12 }

  describe "#call" do
    context "when soak period can be extended" do
      it "adds hours to beta soak period_hours" do
        beta_soak = create(:beta_soak, :active, period_hours: 24, release: release)
        expect {
          described_class.call(beta_soak, additional_hours, user)
        }.to change { beta_soak.reload.period_hours }.from(24).to(36)
      end

      it "extends the soak end time" do
        beta_soak = create(:beta_soak, :active, period_hours: 24, release: release)
        original_end_time = beta_soak.end_time
        described_class.call(beta_soak, additional_hours, user)
        new_end_time = beta_soak.reload.end_time
        expect(new_end_time).to be_within(1.second).of(original_end_time + 12.hours)
      end

      it "extends the beta soak" do
        beta_soak = create(:beta_soak, :active, period_hours: 24, release: release)
        described_class.call(beta_soak, additional_hours, user)
        expect(beta_soak.reload.period_hours).to eq(36)
      end
    end

    it "returns false without extending when additional_hours is invalid" do
      beta_soak = create(:beta_soak, :active, period_hours: 24, release: release)
      expect(described_class.call(beta_soak, 0, user)).to be_nil
      expect(beta_soak.reload.period_hours).to eq(24)
    end

    it "returns false without extending when release is not active" do
      beta_soak = create(:beta_soak, :ended, period_hours: 24, release: release)
      expect(described_class.call(beta_soak, additional_hours, user)).to be_nil
      expect(beta_soak.reload.period_hours).to eq(24)
    end
  end
end
