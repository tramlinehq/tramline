require "rails_helper"
require "webmock/rspec"

describe Webhooks::SvixService do
  let(:train) { create(:train, :with_no_platforms) }
  let(:release) { create(:release, train: train) }
  let(:webhook_integration) { create(:webhook_integration, train: train, svix_app_id: "app_123", status: :active) }
  let(:event_type) { "release.started" }

  before do
    webhook_integration # Ensure SvixIntegration is created
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("HOST_NAME").and_return("test.tramline.app")
    allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
  end

  describe ".trigger_webhook" do
    it "creates a new instance and calls trigger" do
      service_instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(release, event_type).and_return(service_instance)
      allow(service_instance).to receive(:trigger)

      described_class.trigger_webhook(release, event_type, {platform: "android"})

      expect(service_instance).to have_received(:trigger).with({platform: "android"})
    end
  end

  describe "#trigger" do
    let(:service) { described_class.new(release, event_type) }
    let(:valid_payload) { {platform: "android"} }

    context "when webhook integration is available" do
      it "builds payload and sends webhook" do
        allow(service).to receive(:send_webhook)
        allow(webhook_integration).to receive(:send_message).and_return({"id" => "msg_123"})

        service.trigger(valid_payload)

        expect(service).to have_received(:send_webhook).with(hash_including(
          :event_type, :event_source, :event_timestamp, :tramline_payload
        ))
      end
    end

    context "when webhook integration is unavailable" do
      before { webhook_integration.update!(status: :inactive, svix_app_id: nil) }

      it "does not send webhook" do
        allow(service).to receive(:send_webhook)

        service.trigger(valid_payload)

        expect(service).not_to have_received(:send_webhook)
      end
    end

    context "when no webhook integration exists" do
      before { allow(train).to receive(:webhook_integration).and_return(nil) }

      it "does not send webhook" do
        allow(service).to receive(:send_webhook)

        service.trigger(valid_payload)

        expect(service).not_to have_received(:send_webhook)
      end
    end
  end

  describe "integration with actual webhook sending" do
    let(:service) { described_class.new(release, event_type) }
    let(:valid_payload) { {platform: "android"} }
    let(:mocked_integration) { instance_double(SvixIntegration) }

    before do
      allow(train).to receive(:webhook_integration).and_return(mocked_integration)
      allow(mocked_integration).to receive_messages(blank?: false, unavailable?: false)
    end

    it "creates pending event and updates to success" do
      allow(mocked_integration).to receive(:send_message).and_return({"id" => "msg_123"})

      expect {
        service.trigger(valid_payload)
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("success")
      expect(event.event_type).to eq(event_type)
      expect(event.release).to eq(release)
    end

    it "handles webhook delivery failures" do
      original_error = StandardError.new("Connection failed")
      webhook_error = SvixIntegration::WebhookApiError.new(original_error)
      allow(mocked_integration).to receive(:send_message).and_raise(webhook_error)
      allow(service).to receive(:elog)

      expect {
        expect {
          service.trigger(valid_payload)
        }.to raise_error(SvixIntegration::WebhookApiError)
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("failed")
      expect(event.error_message).to eq("Connection failed")
    end
  end

  describe "schema validation" do
    let(:service) { described_class.new(release, "release.started") }
    let(:valid_payload) { {platform: "android"} }
    let(:mocked_integration) { instance_double(SvixIntegration) }

    before do
      allow(train).to receive(:webhook_integration).and_return(mocked_integration)
      allow(mocked_integration).to receive_messages(blank?: false, unavailable?: false, send_message?: {"id" => "msg_123"})
    end

    it "validates payload and sends webhook when valid" do
      expect {
        service.trigger(valid_payload)
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("success")
    end

    it "raises error for unsupported event type" do
      unsupported_service = described_class.new(release, "unsupported.event")
      allow(unsupported_service).to receive(:elog)

      expect {
        unsupported_service.trigger(valid_payload)
      }.to raise_error(ArgumentError, /this event_type does not have a schema associated/)
    end
  end
end
