require "rails_helper"
require "webmock/rspec"

describe Webhooks::SvixService do
  let(:train) { create(:train, :with_no_platforms) }
  let(:svix_integration) { create(:svix_integration, train: train, app_id: "app_123") }
  let(:outgoing_webhook) { create(:outgoing_webhook, train: train) }

  before do
    svix_integration # Ensure SvixIntegration is created
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

  describe "#send_webhook" do
    let(:service) { described_class.new(outgoing_webhook) }

    it "creates pending event and updates to success on successful delivery" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")

      # Mock the SvixIntegration send_message method
      allow(svix_integration).to receive(:send_message).and_return({"id" => "msg_123"})

      expect {
        service.send(:send_webhook, {test: "payload"})
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("success")
      expect(event.response_data).to include("msg_123")
    end

    it "creates pending event and updates to failed on delivery error" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")

      # Mock the SvixIntegration send_message method to raise an error
      allow(svix_integration).to receive(:send_message).and_raise(StandardError.new("Connection failed"))

      expect {
        expect {
          service.send(:send_webhook, {test: "payload"})
        }.to raise_error(StandardError, "Connection failed")
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("failed")
      expect(event.error_message).to eq("Connection failed")
    end

    it "raises error when no SvixIntegration is found" do
      # Create a train without SvixIntegration
      train_without_svix = create(:train, :with_no_platforms)
      webhook_without_svix = create(:outgoing_webhook, train: train_without_svix)
      service_without_svix = described_class.new(webhook_without_svix)

      expect {
        service_without_svix.send(:send_webhook, {test: "payload"})
      }.to raise_error("No SvixIntegration found for train #{train_without_svix.id}")
    end

    it "raises error when SvixIntegration has no app_id" do
      # Update existing SvixIntegration to have no app_id
      svix_integration.update!(app_id: nil)
      
      expect {
        service.send(:send_webhook, {test: "payload"})
      }.to raise_error("No Svix app_id found for train #{train.id}")
    end
  end
end
