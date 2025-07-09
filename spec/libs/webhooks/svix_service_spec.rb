require "rails_helper"
require "webmock/rspec"

describe Webhooks::SvixService do
  let(:train) { create(:train, :with_no_platforms) }
  let(:outgoing_webhook) { create(:outgoing_webhook, train: train) }

  describe ".trigger_for_train" do
    it "triggers webhooks for active webhooks with matching event type" do
      active_webhook = create(:outgoing_webhook, train: train, active: true)
      create(:outgoing_webhook, train: train, active: false)
      create(:outgoing_webhook, :build_events, train: train, active: true)

      service_instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(active_webhook).and_return(service_instance)
      allow(service_instance).to receive(:trigger)

      described_class.trigger_for_train(train, "release_started", {test: "data"})

      expect(service_instance).to have_received(:trigger).with("release_started", {test: "data"})
    end

    it "does not trigger inactive webhooks" do
      create(:outgoing_webhook, train: train, active: false)

      allow(described_class).to receive(:new)

      described_class.trigger_for_train(train, "release_started", {test: "data"})

      expect(described_class).not_to have_received(:new)
    end
  end

  describe ".trigger_webhook" do
    it "creates a new instance and calls trigger" do
      service_instance = instance_double(described_class)
      allow(described_class).to receive(:new).with(outgoing_webhook).and_return(service_instance)
      allow(service_instance).to receive(:trigger)

      described_class.trigger_webhook(outgoing_webhook, "release_started", {test: "data"})

      expect(service_instance).to have_received(:trigger).with("release_started", {test: "data"})
    end
  end

  describe "#trigger" do
    let(:service) { described_class.new(outgoing_webhook) }

    context "when webhook is active and event type matches" do
      it "builds payload and sends webhook" do
        allow(service).to receive(:build_payload).and_call_original
        allow(service).to receive(:send_webhook)

        service.trigger("release_started", {test: "data"})

        expect(service).to have_received(:build_payload).with("release_started", {test: "data"})
        expect(service).to have_received(:send_webhook).with(hash_including(:event_type, :timestamp, :data, :train))
      end
    end

    context "when webhook is inactive" do
      let(:outgoing_webhook) { create(:outgoing_webhook, :inactive, train: train) }

      it "does not send webhook" do
        allow(service).to receive(:send_webhook)
        service.trigger("release_started", {test: "data"})
        expect(service).not_to have_received(:send_webhook)
      end
    end

    context "when event type does not match" do
      it "does not send webhook" do
        allow(service).to receive(:send_webhook)
        service.trigger("build_available", {test: "data"})
        expect(service).not_to have_received(:send_webhook)
      end
    end
  end

  describe "#build_payload" do
    let(:service) { described_class.new(outgoing_webhook) }

    it "builds correct payload structure" do
      payload = service.send(:build_payload, "release_started", {release_id: "123"})

      expect(payload).to include(
        event_type: "release_started",
        timestamp: be_a(String),
        data: {release_id: "123"},
        train: {
          id: train.id,
          name: train.name,
          app_id: train.app_id
        }
      )
    end
  end

  describe "#send_webhook" do
    let(:service) { described_class.new(outgoing_webhook) }

    it "executes without errors" do
      expect { service.send(:send_webhook, {test: "payload"}) }.not_to raise_error
    end
  end
end
