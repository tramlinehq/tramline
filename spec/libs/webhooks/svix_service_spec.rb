require "rails_helper"
require "webmock/rspec"

describe Webhooks::SvixService do
  let(:train) { create(:train, :with_no_platforms) }
  let(:webhook_integration) { create(:webhook_integration, train: train, app_id: "app_123") }
  let(:outgoing_webhook) { create(:outgoing_webhook, train: train) }

  before do
    webhook_integration # Ensure SvixIntegration is created
    # Mock ENV["SVIX_TOKEN"] to avoid nil errors
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")

    # Mock the train's webhook_integration association to return our mocked integration
    allow(train).to receive(:webhook_integration).and_return(webhook_integration)
  end

  describe ".trigger_for_train" do
    it "triggers webhooks for active webhooks with matching event type" do
      active_webhook = create(:outgoing_webhook, train: train, active: true)
      create(:outgoing_webhook, train: train, active: false)
      create(:outgoing_webhook, :rc_events, train: train, active: true)

      service_instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(active_webhook).and_return(service_instance)
      allow(service_instance).to receive(:trigger)

      described_class.trigger_for_train(train, "release.started", {test: "data"})

      expect(service_instance).to have_received(:trigger).with("release.started", {test: "data"})
    end

    it "does not trigger inactive webhooks" do
      create(:outgoing_webhook, train: train, active: false)

      allow(described_class).to receive(:new)

      described_class.trigger_for_train(train, "release.started", {test: "data"})

      expect(described_class).not_to have_received(:new)
    end
  end

  describe ".trigger_webhook" do
    it "creates a new instance and calls trigger" do
      service_instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(outgoing_webhook).and_return(service_instance)
      allow(service_instance).to receive(:trigger)

      described_class.trigger_webhook(outgoing_webhook, "release.started", {test: "data"})

      expect(service_instance).to have_received(:trigger).with("release.started", {test: "data"})
    end
  end

  describe "#trigger" do
    let(:service) { described_class.new(outgoing_webhook) }

    context "when webhook is active and event type matches" do
      it "builds payload and sends webhook" do
        allow(service).to receive(:build_payload).and_call_original
        allow(service).to receive(:send_webhook)

        service.trigger("release.started", {test: "data"})

        expect(service).to have_received(:build_payload).with("release.started", {test: "data"})
        expect(service).to have_received(:send_webhook).with(hash_including(:event_type, :timestamp, :data, :train))
      end
    end

    context "when webhook is inactive" do
      let(:outgoing_webhook) { create(:outgoing_webhook, :inactive, train: train) }

      it "does not send webhook" do
        allow(service).to receive(:send_webhook)
        service.trigger("release.started", {test: "data"})
        expect(service).not_to have_received(:send_webhook)
      end
    end

    context "when event type does not match" do
      it "does not send webhook" do
        allow(service).to receive(:send_webhook)
        service.trigger("rc.finished", {test: "data"})
        expect(service).not_to have_received(:send_webhook)
      end
    end
  end

  describe "#build_payload" do
    let(:service) { described_class.new(outgoing_webhook) }

    it "builds correct payload structure" do
      payload = service.send(:build_payload, "release.started", {release_id: "123"})

      expect(payload).to include(
        event_type: "release.started",
        timestamp: be_a(String),
        data: {release_id: "123"},
        train: train.webhook_params
      )
    end
  end

  describe ".create_endpoint_for_webhook" do
    before do
      # Mock the create_endpoint method to avoid real HTTP calls
      allow(webhook_integration).to receive(:create_endpoint).and_return(instance_double(Svix::EndpointOut, id: "ep_123"))
    end

    it "creates OutgoingWebhook record" do
      expect {
        described_class.create_endpoint_for_webhook(train, "https://example.com/webhook", event_types: ["release.started"], description: "Test webhook")
      }.to change(OutgoingWebhook, :count).by(1)
    end

    it "creates OutgoingWebhook with correct attributes" do
      result = described_class.create_endpoint_for_webhook(train, "https://example.com/webhook", event_types: ["release.started"], description: "Test webhook")
      expect(result).to be_a(OutgoingWebhook)
      expect(result.url).to eq("https://example.com/webhook")
      expect(result.event_types).to eq(["release.started"])
      expect(result.description).to eq("Test webhook")
      expect(webhook_integration).to have_received(:create_endpoint).with("https://example.com/webhook", event_types: ["release.started"])
    end

    it "creates active OutgoingWebhook with correct svix_endpoint_id" do
      result = described_class.create_endpoint_for_webhook(train, "https://example.com/webhook")
      expect(result.active).to be true
      expect(result.svix_endpoint_id).to eq("ep_123")
      expect(webhook_integration).to have_received(:create_endpoint).with("https://example.com/webhook", event_types: ["release.started", "release.ended", "rc.finished"])
    end

    it "uses default event types when not specified" do
      result = described_class.create_endpoint_for_webhook(train, "https://example.com/webhook")
      expect(result.event_types).to eq(["release.started", "release.ended", "rc.finished"])
      expect(webhook_integration).to have_received(:create_endpoint).with("https://example.com/webhook", event_types: ["release.started", "release.ended", "rc.finished"])
    end

    it "returns nil when webhook integration has no app_id" do
      webhook_integration.update!(app_id: nil)
      result = described_class.create_endpoint_for_webhook(train, "https://example.com/webhook")
      expect(result).to be_nil
    end

    it "returns nil when train has no webhook integration" do
      train_without_webhook = create(:train, :with_no_platforms)
      result = described_class.create_endpoint_for_webhook(train_without_webhook, "https://example.com/webhook")
      expect(result).to be_nil
    end
  end

  describe "#send_webhook" do
    let(:service) { described_class.new(outgoing_webhook) }

    before do
      # Mock the send_message method to avoid real HTTP calls
      allow(webhook_integration).to receive(:send_message).and_return({"id" => "msg_123"})
    end

    it "creates pending event and updates to success on successful delivery" do
      expect {
        service.send(:send_webhook, {test: "payload"})
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("success")
      expect(event.response_data).to include("msg_123")
      expect(webhook_integration).to have_received(:send_message)
    end

    it "creates pending event and updates to failed on delivery error" do
      # Override the mock to raise an error for this specific test
      allow(webhook_integration).to receive(:send_message).and_raise(StandardError.new("Connection failed"))

      expect {
        expect {
          service.send(:send_webhook, {test: "payload"})
        }.to raise_error(StandardError, "Connection failed")
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("failed")
      expect(event.error_message).to eq("Connection failed")
    end

    it "raises error when no webhook integration is found" do
      # Create a train without webhook integration
      train_without_webhook = create(:train, :with_no_platforms)
      webhook_without_integration = create(:outgoing_webhook, train: train_without_webhook)
      service_without_integration = described_class.new(webhook_without_integration)

      expect {
        service_without_integration.send(:send_webhook, {test: "payload"})
      }.to raise_error("No SvixIntegration found for train #{train_without_webhook.id}")
    end

    it "raises error when webhook integration has no app_id" do
      # Update existing webhook integration to have no app_id
      webhook_integration.update!(app_id: nil)
      expect {
        service.send(:send_webhook, {test: "payload"})
      }.to raise_error("No Svix app_id found for train #{train.id}")
    end
  end
end
