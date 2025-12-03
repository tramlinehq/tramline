# frozen_string_literal: true

require "rails_helper"

describe Coordinators::SoakPeriod::End do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:user) { create(:user) }

  describe "#call" do
    context "when soak period can be ended" do
      it "ends beta soak by setting ended_at" do
        beta_soak = create(:beta_soak, :active, release: release)
        described_class.call(beta_soak, user)
        expect(beta_soak.reload.ended_at).to be_present
      end

      it "continues blocked workflow" do
        beta_soak = create(:beta_soak, :active, release: release)
        allow(Coordinators::Signals).to receive(:continue_after_soak_period!).with(release)

        described_class.call(beta_soak, user)

        expect(Coordinators::Signals).to have_received(:continue_after_soak_period!).with(release)
      end
    end

    it "returns false without ending soak when release is not active" do
      beta_soak = create(:beta_soak, :active, release: release)
      release.update!(status: "stopped")

      expect(described_class.call(beta_soak, user)).to be_nil
      expect(beta_soak.reload.ended_at).to be_nil
    end

    it "does nothing when it's already ended" do
      beta_soak = create(:beta_soak, :ended, release: release)
      expect(described_class.call(beta_soak, user)).to be_nil
    end
  end
end
