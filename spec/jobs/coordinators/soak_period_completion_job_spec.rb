require "rails_helper"

describe Coordinators::SoakPeriodCompletionJob do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }

  describe "#perform" do
    subject(:perform) { described_class.new.perform(release.id) }

    context "when soak period is completed" do
      before do
        release.update!(soak_started_at: 25.hours.ago)
      end

      it "creates a completion stamp" do
        expect { perform }.to change { release.stamps.count }.by(1)
        expect(release.stamps.last.reason).to eq("soak_period_completed")
        expect(release.stamps.last.kind).to eq("notice")
      end

      it "continues the blocked workflow" do
        expect(Coordinators::Signals).to receive(:continue_after_soak_period!).with(release)
        perform
      end
    end

    context "when soak period is not completed" do
      before do
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "does not create a stamp" do
        expect { perform }.not_to change { release.stamps.count }
      end

      it "does not continue workflow" do
        expect(Coordinators::Signals).not_to receive(:continue_after_soak_period!)
        perform
      end
    end

    context "when soak period was not started" do
      it "does not create a stamp" do
        expect { perform }.not_to change { release.stamps.count }
      end

      it "does not continue workflow" do
        expect(Coordinators::Signals).not_to receive(:continue_after_soak_period!)
        perform
      end
    end
  end
end
