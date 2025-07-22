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

        valid_payload = {
          full_changelog: ["commit 1", "commit 2"],
          release_version: "1.0.0",
          release_branch_name: "r/main/2025-01-09",
          platform: "android"
        }
        service.trigger("release.started", valid_payload)

        expect(service).to have_received(:build_payload).with("release.started", valid_payload)
        expect(service).to have_received(:send_webhook).with(hash_including(:event_type, :timestamp, :data, :train))
      end
    end

    context "when webhook is inactive" do
      let(:outgoing_webhook) { create(:outgoing_webhook, :inactive, train: train) }

      it "does not send webhook" do
        allow(service).to receive(:send_webhook)
        valid_payload = {
          full_changelog: ["commit 1", "commit 2"],
          release_version: "1.0.0",
          release_branch_name: "r/main/2025-01-09",
          platform: "android"
        }
        service.trigger("release.started", valid_payload)
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
      valid_payload = {
        full_changelog: ["commit 1", "commit 2"],
        release_version: "1.0.0",
        release_branch_name: "r/main/2025-01-09",
        platform: "android"
      }
      payload = service.send(:build_payload, "release.started", valid_payload)

      expect(payload).to include(
        event_type: "release.started",
        timestamp: be_a(String),
        data: valid_payload,
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

    it "creates inactive OutgoingWebhook with error when endpoint creation fails" do
      allow(webhook_integration).to receive(:create_endpoint).and_raise(HTTP::Error.new("Network error"))

      expect {
        expect {
          described_class.create_endpoint_for_webhook(train, "https://example.com/webhook")
        }.to raise_error(HTTP::Error, "Network error")
      }.to change(OutgoingWebhook, :count).by(1)

      webhook = OutgoingWebhook.last
      expect(webhook.active).to be false
      expect(webhook.url).to eq("https://example.com/webhook")
      expect(webhook.svix_endpoint_id).to be_nil
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

    it "creates pending event and updates to failed on HTTP error" do
      allow(webhook_integration).to receive(:send_message).and_raise(HTTP::Error.new("Network error"))

      expect {
        expect {
          service.send(:send_webhook, {test: "payload"})
        }.to raise_error(HTTP::Error, "Network error")
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("failed")
      expect(event.error_message).to eq("Network error: Network error")
    end

    it "creates pending event and updates to failed on Faraday error" do
      allow(webhook_integration).to receive(:send_message).and_raise(Faraday::Error.new("Connection failed"))

      expect {
        expect {
          service.send(:send_webhook, {test: "payload"})
        }.to raise_error(Faraday::Error, "Connection failed")
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("failed")
      expect(event.error_message).to eq("Network error: Connection failed")
    end

    it "creates pending event and updates to failed on standard error" do
      allow(webhook_integration).to receive(:send_message).and_raise(StandardError.new("General error"))

      expect {
        expect {
          service.send(:send_webhook, {test: "payload"})
        }.to raise_error(StandardError, "General error")
      }.to change(OutgoingWebhookEvent, :count).by(1)

      event = OutgoingWebhookEvent.last
      expect(event.status).to eq("failed")
      expect(event.error_message).to eq("General error")
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

  describe "schema validation" do
    let(:valid_rc_finished_payload) do
      {
        full_changelog: ["commit 1", "commit 2"],
        diff_changelog: ["commit 1"],
        release_version: "1.0.0",
        build_number: "123",
        release_branch_name: "r/main/2025-01-09",
        platform: "android"
      }
    end

    let(:valid_release_started_payload) do
      {
        full_changelog: ["commit 1", "commit 2"],
        release_version: "1.0.0",
        release_branch_name: "r/main/2025-01-09",
        platform: "ios"
      }
    end

    let(:valid_release_ended_payload) do
      {
        full_changelog: ["commit 1", "commit 2"],
        diff_changelog: ["commit 1"],
        release_version: "1.0.0",
        release_branch_name: "r/main/2025-01-09",
        platform: "android"
      }
    end

    let(:invalid_payload) do
      {
        full_changelog: "not an array",
        platform: "invalid_platform"
      }
    end

    describe "#validate_payload_schema!" do
      it "validates payload against rc.finished schema" do
        service = described_class.new(outgoing_webhook)

        expect {
          service.send(:validate_payload_schema!, "rc.finished", valid_rc_finished_payload)
        }.not_to raise_error
      end

      it "validates payload against release.started schema" do
        service = described_class.new(outgoing_webhook)

        expect {
          service.send(:validate_payload_schema!, "release.started", valid_release_started_payload)
        }.not_to raise_error
      end

      it "validates payload against release.ended schema" do
        service = described_class.new(outgoing_webhook)

        expect {
          service.send(:validate_payload_schema!, "release.ended", valid_release_ended_payload)
        }.not_to raise_error
      end

      it "raises error for invalid payload against rc.finished schema" do
        service = described_class.new(outgoing_webhook)

        expect {
          service.send(:validate_payload_schema!, "rc.finished", invalid_payload)
        }.to raise_error(ArgumentError, /Webhook payload validation failed/)
      end

      it "logs validation errors" do
        service = described_class.new(outgoing_webhook)
        allow(service).to receive(:elog)

        expect {
          service.send(:validate_payload_schema!, "rc.finished", invalid_payload)
        }.to raise_error(ArgumentError)

        expect(service).to have_received(:elog).with(
          /Webhook payload validation failed for rc.finished/,
          level: :error
        )
      end

      it "skips validation for unknown event types" do
        service = described_class.new(outgoing_webhook)

        expect {
          service.send(:validate_payload_schema!, "unknown.event", {})
        }.not_to raise_error
      end

      it "skips validation when schema does not exist" do
        service = described_class.new(outgoing_webhook)
        allow(service).to receive(:schema_for_event).and_return(nil)

        expect {
          service.send(:validate_payload_schema!, "unknown.event", {})
        }.not_to raise_error
      end
    end

    describe "#schema_for_event" do
      it "returns correct schema for rc.finished" do
        service = described_class.new(outgoing_webhook)
        expected_schema = JSON.parse(Rails.root.join("config/schema/webhook_rc_finished.json").read)

        expect(service.send(:schema_for_event, "rc.finished")).to eq(expected_schema)
      end

      it "returns correct schema for release.started" do
        service = described_class.new(outgoing_webhook)
        expected_schema = JSON.parse(Rails.root.join("config/schema/webhook_release_started.json").read)

        expect(service.send(:schema_for_event, "release.started")).to eq(expected_schema)
      end

      it "returns correct schema for release.ended" do
        service = described_class.new(outgoing_webhook)
        expected_schema = JSON.parse(Rails.root.join("config/schema/webhook_release_ended.json").read)

        expect(service.send(:schema_for_event, "release.ended")).to eq(expected_schema)
      end

      it "returns nil for unknown event types" do
        service = described_class.new(outgoing_webhook)

        expect(service.send(:schema_for_event, "unknown.event")).to be_nil
      end
    end

    describe "integration with trigger method" do
      it "validates payload before sending webhook" do
        # Update webhook to support rc.finished event type
        allow(outgoing_webhook).to receive_messages(event_types: ["rc.finished"], active?: true)

        service = described_class.new(outgoing_webhook)
        allow(service).to receive(:send_webhook)
        allow(service).to receive(:validate_payload_schema!)

        service.trigger("rc.finished", valid_rc_finished_payload)

        expect(service).to have_received(:validate_payload_schema!).with("rc.finished", valid_rc_finished_payload)
      end

      it "prevents webhook sending when validation fails" do
        # Update webhook to support rc.finished event type
        allow(outgoing_webhook).to receive_messages(event_types: ["rc.finished"], active?: true)

        service = described_class.new(outgoing_webhook)
        allow(service).to receive(:send_webhook)
        allow(service).to receive(:validate_payload_schema!).and_raise(ArgumentError, "Validation failed")

        expect {
          service.trigger("rc.finished", invalid_payload)
        }.to raise_error(ArgumentError, "Validation failed")

        expect(service).not_to have_received(:send_webhook)
      end
    end
  end
end
