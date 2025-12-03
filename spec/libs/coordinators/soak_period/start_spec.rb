# frozen_string_literal: true

require "rails_helper"

describe Coordinators::SoakPeriod::Start do
  let(:app) { create(:app, :android) }
  let(:train) { create(:train, app: app, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, train:) }

  describe "#call" do
    context "when soak period is enabled and beta release exists" do
      before do
        create(:beta_release, release_platform_run: create(:release_platform_run, release:))
      end

      it "creates beta soak" do
        expect {
          described_class.call(release)
        }.to change(BetaSoak, :count).by(1)
      end

      it "sets correct attributes on beta soak" do
        freeze_time do
          described_class.call(release)
          beta_soak = release.reload.beta_soak

          expect(beta_soak.started_at).to eq(Time.current)
          expect(beta_soak.period_hours).to eq(24)
        end
      end

      it "schedules completion job" do
        allow(Coordinators::SoakPeriodExpiredJob).to receive(:perform_in)

        described_class.call(release)
        beta_soak = release.reload.beta_soak

        expect(Coordinators::SoakPeriodExpiredJob).to have_received(:perform_in).with(24.hours, beta_soak.id)
      end

      it "does not create if beta soak already exists" do
        create(:beta_soak, release: release)
        expect { described_class.call(release) }.not_to change(BetaSoak, :count)
      end
    end

    it "does not create beta soak when soak period is disabled" do
      create(:beta_release, release_platform_run: create(:release_platform_run, release:))
      train.update!(soak_period_enabled: false)

      expect {
        described_class.call(release)
      }.not_to change(BetaSoak, :count)
    end

    it "does not create beta soak when no beta release exists" do
      expect {
        described_class.call(release)
      }.not_to change(BetaSoak, :count)
    end
  end
end
