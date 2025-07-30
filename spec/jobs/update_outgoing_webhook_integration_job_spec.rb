# frozen_string_literal: true

require "rails_helper"

describe UpdateOutgoingWebhookIntegrationJob do
  before do
    allow_any_instance_of(SvixIntegration).to receive(:create_app!).and_return(true)
    allow_any_instance_of(SvixIntegration).to receive(:delete_app!).and_return(true)
  end

  describe "#perform" do
    context "when enabled is true (default)" do
      it "creates webhook integration when it doesn't exist" do
        train = create(:train, webhooks_enabled: true)

        expect(train.reload.webhook_integration).not_to be_present

        expect {
          described_class.new.perform(train.id, true)
        }.to change { train.reload.webhook_integration }.from(nil)

        expect(train.reload.webhook_integration).to be_present
      end

      it "creates webhook integration when called without enabled parameter (defaults to true)" do
        train = create(:train, webhooks_enabled: true)

        expect(train.reload.webhook_integration).not_to be_present

        expect {
          described_class.new.perform(train.id)
        }.to change { train.reload.webhook_integration }.from(nil)

        expect(train.reload.webhook_integration).to be_present
      end

      it "does nothing when webhook integration already exists and is available" do
        train = create(:train, webhooks_enabled: true)
        create(:webhook_integration, train: train)

        expect {
          described_class.new.perform(train.id, true)
        }.not_to change { train.reload.webhook_integration }
      end
    end

    context "when enabled is false" do
      it "deletes webhook integration when it exists and is available" do
        train = create(:train)
        webhook_integration = create(:webhook_integration, train: train)

        expect {
          described_class.new.perform(train.id, false)
        }.to change { SvixIntegration.exists?(webhook_integration.id) }.from(true).to(false)
      end

      it "does nothing when webhook integration doesn't exist" do
        train = create(:train)

        expect { described_class.new.perform(train.id, false) }.not_to raise_error
        expect(train.reload.webhook_integration).to be_nil
      end

      it "does nothing when webhook integration is not available" do
        train = create(:train)
        webhook_integration = create(:webhook_integration, :inactive, train: train)

        expect { described_class.new.perform(train.id, false) }.not_to raise_error
        expect(webhook_integration.reload).to be_persisted
      end
    end

    context "when train doesn't exist" do
      it "raises ActiveRecord::RecordNotFound" do
        non_existent_id = "00000000-0000-0000-0000-000000000000"
        expect { described_class.new.perform(non_existent_id, true) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
