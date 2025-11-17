# frozen_string_literal: true

require "rails_helper"

describe Coordinators::SoakPeriod::Extend do
  let(:train) { create(:train, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_pilot) { release.train.app.organization.owner }
  let(:other_user) { create(:user, :as_developer, member_organization: release.train.app.organization) }

  describe "#call" do
    context "when soak period is active" do
      before do
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "extends the soak period by the specified hours" do
        original_end_time = release.soak_end_time

        result = described_class.new(release, 12, release_pilot).call
        expect(result).to be_truthy

        new_end_time = release.reload.soak_end_time
        expect(new_end_time).to be_within(1.second).of(original_end_time + 12.hours)
      end

      it "adds hours to soak_started_at to extend the end time" do
        original_started_at = release.soak_started_at

        described_class.new(release, 24, release_pilot).call

        new_started_at = release.reload.soak_started_at
        expect(new_started_at).to be_within(1.second).of(original_started_at + 24.hours)
      end

      it "stamps an event when soak is extended" do
        expect(release).to receive(:event_stamp!).with(hash_including(reason: :soak_period_extended))

        described_class.new(release, 6, release_pilot).call
      end

      it "uses with_lock to prevent race conditions" do
        expect(release).to receive(:with_lock).and_call_original

        described_class.new(release, 12, release_pilot).call
      end

      context "with different extension amounts" do
        it "extends by 1 hour" do
          original_end_time = release.soak_end_time

          described_class.new(release, 1, release_pilot).call

          expect(release.reload.soak_end_time).to be_within(1.second).of(original_end_time + 1.hour)
        end

        it "extends by 48 hours" do
          original_end_time = release.soak_end_time

          described_class.new(release, 48, release_pilot).call

          expect(release.reload.soak_end_time).to be_within(1.second).of(original_end_time + 48.hours)
        end

        it "extends by 168 hours (max)" do
          original_end_time = release.soak_end_time

          described_class.new(release, 168, release_pilot).call

          expect(release.reload.soak_end_time).to be_within(1.second).of(original_end_time + 168.hours)
        end
      end

      context "authorization" do
        it "succeeds when user is release pilot" do
          result = described_class.new(release, 12, release_pilot).call
          expect(result).to be_truthy
        end

        it "fails when user is not release pilot" do
          result = described_class.new(release, 12, other_user).call
          expect(result).to be_falsey
        end

        it "fails when user is nil" do
          result = described_class.new(release, 12, nil).call
          expect(result).to be_falsey
        end
      end

      context "with invalid additional_hours" do
        it "returns false when additional_hours is 0" do
          result = described_class.new(release, 0, release_pilot).call
          expect(result).to be_falsey
        end

        it "returns false when additional_hours is negative" do
          result = described_class.new(release, -5, release_pilot).call
          expect(result).to be_falsey
        end

        it "does not modify soak_started_at with invalid hours" do
          original_started_at = release.soak_started_at

          described_class.new(release, 0, release_pilot).call

          expect(release.reload.soak_started_at).to eq(original_started_at)
        end
      end
    end

    context "when soak period is not active" do
      it "returns false when soak has not started" do
        result = described_class.new(release, 12, release_pilot).call
        expect(result).to be_falsey
      end

      it "returns false when soak has already completed" do
        release.update!(soak_started_at: 25.hours.ago)
        result = described_class.new(release, 12, release_pilot).call
        expect(result).to be_falsey
      end

      it "does not modify soak_started_at when soak not active" do
        original_time = nil
        release.update!(soak_started_at: original_time)

        expect {
          described_class.new(release, 12, release_pilot).call
        }.not_to change { release.reload.soak_started_at }
      end
    end

    context "when release is not active" do
      before do
        release.update!(status: "stopped", soak_started_at: 1.hour.ago)
      end

      it "returns false" do
        result = described_class.new(release, 12, release_pilot).call
        expect(result).to be_falsey
      end

      it "does not extend the soak period" do
        original_started_at = release.soak_started_at

        described_class.new(release, 12, release_pilot).call

        expect(release.reload.soak_started_at).to eq(original_started_at)
      end
    end
  end
end
