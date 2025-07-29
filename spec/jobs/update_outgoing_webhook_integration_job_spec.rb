# frozen_string_literal: true

require "rails_helper"

describe UpdateOutgoingWebhookIntegrationJob do
  let(:train) { create(:train) }
  let(:svix_double) { instance_double(SvixIntegration, create_app!: true) }

  describe "#perform" do
    context "when enabled is true (default)" do
      it "creates webhook integration when it doesn't exist" do
        allow(Train).to receive(:find).with(train.id).and_return(train)
        allow(train).to receive_messages(webhook_integration: nil, create_webhook_integration!: svix_double)

        described_class.new.perform(train.id, true)

        expect(train).to have_received(:create_webhook_integration!)
      end

      it "creates webhook integration when called without enabled parameter (defaults to true)" do
        allow(Train).to receive(:find).with(train.id).and_return(train)
        allow(train).to receive_messages(webhook_integration: nil, create_webhook_integration!: svix_double)

        described_class.new.perform(train.id)

        expect(train).to have_received(:create_webhook_integration!)
      end

      it "does nothing when webhook integration already exists and is available" do
        webhook_integration = instance_double(SvixIntegration, available?: true)
        allow(Train).to receive(:find).with(train.id).and_return(train)
        allow(train).to receive_messages(webhook_integration: webhook_integration, create_webhook_integration!: nil)

        described_class.new.perform(train.id, true)

        expect(train).not_to have_received(:create_webhook_integration!)
      end
    end

    context "when enabled is false" do
      it "deletes webhook integration when it exists and is available" do
        webhook_integration = instance_double(SvixIntegration)
        allow(Train).to receive(:find).with(train.id).and_return(train)
        allow(train).to receive(:webhook_integration).and_return(webhook_integration)
        allow(webhook_integration).to receive_messages(available?: true, delete_app!: nil, destroy!: nil)

        described_class.new.perform(train.id, false)

        expect(webhook_integration).to have_received(:delete_app!)
        expect(webhook_integration).to have_received(:destroy!)
      end

      it "does nothing when webhook integration doesn't exist" do
        allow(Train).to receive(:find).with(train.id).and_return(train)
        allow(train).to receive(:webhook_integration).and_return(nil)

        expect { described_class.new.perform(train.id, false) }.not_to raise_error
      end

      it "does nothing when webhook integration is not available" do
        webhook_integration = instance_double(SvixIntegration, available?: false)
        allow(Train).to receive(:find).with(train.id).and_return(train)
        allow(train).to receive(:webhook_integration).and_return(webhook_integration)

        expect { described_class.new.perform(train.id, false) }.not_to raise_error
      end
    end
  end
end
