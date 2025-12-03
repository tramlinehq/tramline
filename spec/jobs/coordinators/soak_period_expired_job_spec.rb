require "rails_helper"

describe Coordinators::SoakPeriodExpiredJob do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:beta_soak) { create(:beta_soak, :active, release:) }

  describe "#perform" do
    it "does nothing if beta soak is missing" do
      id = beta_soak.id
      beta_soak.destroy
      expect { described_class.new.perform(id) }.not_to raise_error
    end

    it "calls Coordinators::SoakPeriod::End.call" do
      allow(Coordinators::SoakPeriod::End).to receive(:call).with(beta_soak, nil)
      described_class.new.perform(beta_soak.id)
      expect(Coordinators::SoakPeriod::End).to have_received(:call).with(beta_soak, nil)
    end

    it "reschedules the job if soak period has not expired" do
      allow(described_class).to receive(:perform_in).with(82800, beta_soak.id)

      freeze_time do
        described_class.new.perform(beta_soak.id)
        expect(described_class).to have_received(:perform_in).with(82800, beta_soak.id)
      end
    end
  end
end
