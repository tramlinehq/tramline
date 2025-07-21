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
    let(:train) { create(:train, :with_no_platforms) }
    let(:webhook) { create(:outgoing_webhook, train: train) }
    let(:event) { create(:outgoing_webhook_event, train: train, outgoing_webhook: webhook) }

    it "belongs to train" do
      expect(event.train).to eq(train)
    end

    it "belongs to outgoing_webhook" do
      expect(event.outgoing_webhook).to eq(webhook)
    end
  end

  describe "scopes" do
    let(:train) { create(:train, :with_no_platforms) }
    let(:webhook) { create(:outgoing_webhook, train: train) }
    let!(:recent_event) { create(:outgoing_webhook_event, train: train, outgoing_webhook: webhook, event_timestamp: 1.hour.ago) }
    let!(:old_event) { create(:outgoing_webhook_event, train: train, outgoing_webhook: webhook, event_timestamp: 1.day.ago) }

    describe ".recent" do
      it "orders by event_timestamp desc" do
        expect(described_class.recent).to eq([recent_event, old_event])
      end
    end

    describe ".for_webhook" do
      it "returns events for specific webhook" do
        expect(described_class.for_webhook(webhook)).to include(recent_event, old_event)
      end
    end
  end

  describe "status methods" do
    it "returns true for successful? when status is success" do
      event = build(:outgoing_webhook_event, :successful)
      expect(event.successful?).to be true
    end

    it "returns true for failed? when status is failed" do
      event = build(:outgoing_webhook_event, :failed)
      expect(event.failed?).to be true
    end
  end
end
