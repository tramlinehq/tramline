require "rails_helper"
require "webmock/rspec"

describe OutgoingWebhook do
  it "has a valid factory" do
    expect(create(:outgoing_webhook)).to be_valid
  end

  describe "validations" do
    it "requires a URL" do
      webhook = build(:outgoing_webhook, url: nil)
      expect(webhook).not_to be_valid
      expect(webhook.errors[:url]).to include("can't be blank")
    end

    it "requires a valid HTTP/HTTPS URL" do
      webhook = build(:outgoing_webhook, url: "ftp://example.com")
      expect(webhook).not_to be_valid
      expect(webhook.errors[:url]).to include("is invalid")
    end

    it "accepts valid HTTP URLs" do
      webhook = build(:outgoing_webhook, url: "http://example.com/webhook")
      expect(webhook).to be_valid
    end

    it "accepts valid HTTPS URLs" do
      webhook = build(:outgoing_webhook, url: "https://example.com/webhook")
      expect(webhook).to be_valid
    end

    it "requires event_types" do
      webhook = build(:outgoing_webhook, event_types: [])
      expect(webhook).not_to be_valid
      expect(webhook.errors[:event_types]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to a train" do
      train = create(:train, :with_no_platforms)
      webhook = create(:outgoing_webhook, train: train)
      expect(webhook.train).to eq(train)
    end
  end

  describe "scopes" do
    let(:train) { create(:train, :with_no_platforms) }
    let!(:active_webhook) { create(:outgoing_webhook, train: train, active: true) }
    let!(:inactive_webhook) { create(:outgoing_webhook, :inactive, train: train) }

    describe ".active" do
      it "returns only active webhooks" do
        expect(described_class.active).to include(active_webhook)
        expect(described_class.active).not_to include(inactive_webhook)
      end
    end

    describe ".for_event_type" do
      let!(:release_webhook) { create(:outgoing_webhook, train: train) }
      let!(:rc_webhook) { create(:outgoing_webhook, :rc_events, train: train) }

      it "returns webhooks for specific event type" do
        expect(described_class.for_event_type("release.started")).to include(release_webhook)
        expect(described_class.for_event_type("release.started")).not_to include(rc_webhook)
      end
    end
  end
end
