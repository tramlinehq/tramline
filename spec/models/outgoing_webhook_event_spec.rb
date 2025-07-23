require "rails_helper"

describe OutgoingWebhookEvent do
  it "has a valid factory" do
    expect(create(:outgoing_webhook_event)).to be_valid
  end

  describe "validations" do
    it "requires event_timestamp" do
      event = build(:outgoing_webhook_event, event_timestamp: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_timestamp]).to include("can't be blank")
    end

    it "requires status" do
      event = build(:outgoing_webhook_event, status: nil)
      expect(event).not_to be_valid
      expect(event.errors[:status]).to include("can't be blank")
    end
  end

  describe "associations" do
    let(:release) { create(:release) }
    let(:event) { create(:outgoing_webhook_event, release: release) }

    it "belongs to release" do
      expect(event.release).to eq(release)
    end
  end

  describe "scopes" do
    let(:release) { create(:release) }
    let(:webhook) { create(:outgoing_webhook, train: train) }
    let!(:recent_event) { create(:outgoing_webhook_event, release:, event_timestamp: 1.hour.ago) }
    let!(:old_event) { create(:outgoing_webhook_event, release:, event_timestamp: 1.day.ago) }

    describe ".recent" do
      it "orders by event_timestamp desc" do
        expect(described_class.recent).to eq([recent_event, old_event])
      end
    end
  end

  describe "status methods" do
    it "returns true for success? when status is success" do
      event = build(:outgoing_webhook_event, :success)
      expect(event.success?).to be true
    end

    it "returns true for failed? when status is failed" do
      event = build(:outgoing_webhook_event, :failed)
      expect(event.failed?).to be true
    end
  end
end
