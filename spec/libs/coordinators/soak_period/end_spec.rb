# frozen_string_literal: true

require "rails_helper"

describe Coordinators::SoakPeriod::End do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_pilot) { release.train.app.organization.owner }
  let(:other_user) { create(:user, :as_developer, member_organization: release.train.app.organization) }

  describe "#call" do
    context "when soak period is active" do
      before do
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "ends the soak period early" do
        freeze_time do
          result = described_class.new(release, release_pilot).call
          expect(result).to be_truthy
          expect(release.reload.soak_period_completed?).to eq(true)
        end
      end

      it "sets soak_started_at to make soak_end_time equal to current time" do
        freeze_time do
          described_class.new(release, release_pilot).call
          expect(release.reload.soak_end_time).to be_within(1.second).of(Time.current)
        end
      end

      it "stamps an event when soak ends early" do
        expect(release).to receive(:event_stamp!).with(hash_including(reason: :soak_period_ended_early))

        described_class.new(release, release_pilot).call
      end

      it "uses with_lock to prevent race conditions" do
        expect(release).to receive(:with_lock).and_call_original

        described_class.new(release, release_pilot).call
      end

      context "authorization" do
        it "succeeds when user is release pilot" do
          result = described_class.new(release, release_pilot).call
          expect(result).to be_truthy
        end

        it "fails when user is not release pilot" do
          result = described_class.new(release, other_user).call
          expect(result).to be_falsey
        end

        it "fails when user is nil" do
          result = described_class.new(release, nil).call
          expect(result).to be_falsey
        end
      end
    end

    context "when soak period is not active" do
      it "returns false when soak has not started" do
        result = described_class.new(release, release_pilot).call
        expect(result).to be_falsey
      end

      it "returns false when soak has already completed" do
        release.update!(soak_started_at: 25.hours.ago)
        result = described_class.new(release, release_pilot).call
        expect(result).to be_falsey
      end

      it "does not modify soak_started_at when soak not active" do
        original_time = nil
        release.update!(soak_started_at: original_time)

        expect {
          described_class.new(release, release_pilot).call
        }.not_to change { release.reload.soak_started_at }
      end
    end

    context "when release is not active" do
      before do
        release.update!(status: "stopped", soak_started_at: 1.hour.ago)
      end

      it "returns false" do
        result = described_class.new(release, release_pilot).call
        expect(result).to be_falsey
      end

      it "does not end the soak period" do
        original_started_at = release.soak_started_at

        described_class.new(release, release_pilot).call

        expect(release.reload.soak_started_at).to eq(original_started_at)
      end
    end
  end
end
