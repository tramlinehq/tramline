require "rails_helper"

describe SvixIntegration do
  let(:train) { create(:train, :with_no_platforms) }
  let(:webhook_integration) { create(:webhook_integration, train: train) }

  describe "associations" do
    it "belongs to train" do
      expect(webhook_integration.train).to eq(train)
    end
  end

  describe "validations" do
    it "validates presence of status" do
      webhook_integration.status = nil
      expect(webhook_integration).not_to be_valid
      expect(webhook_integration.errors[:status]).to include("can't be blank")
    end

    it "validates uniqueness of app_id" do
      create(:webhook_integration, svix_app_id: "duplicate_id", train: train)
      new_integration = build(:webhook_integration, svix_app_id: "duplicate_id", train: create(:train, :with_no_platforms))
      expect(new_integration).not_to be_valid
      expect(new_integration.errors[:svix_app_id]).to include("has already been taken")
    end

    it "allows nil svix_app_id" do
      webhook_integration.svix_app_id = nil
      expect(webhook_integration).to be_valid
    end
  end

  describe "enums" do
    it "defines status enum with correct values" do
      expect(described_class.statuses).to eq({"active" => "active", "inactive" => "inactive"})
    end
  end

  describe "#create_app!" do
    let(:test_webhook_integration) { create(:webhook_integration, train: train, svix_app_id: nil) }
    let(:svix_client) { instance_double(Svix::Client) }
    let(:response) { instance_double(Svix::ApplicationOut, id: "app_123") }

    before do
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
      allow(Svix::Client).to receive(:new).and_return(svix_client)
      allow(svix_client).to receive(:application).and_return(instance_double(Svix::Application))
      allow(test_webhook_integration).to receive(:elog)
    end

    it "creates a Svix app successfully" do
      allow(svix_client.application).to receive(:create).and_return(response)

      test_webhook_integration.create_app!

      expect(test_webhook_integration.reload.svix_app_id).to eq("app_123")
      expect(test_webhook_integration.status).to eq("active")
    end

    context "with retry logic" do
      let(:server_error) do
        error = StandardError.new("Internal Server Error")
        def error.code
          500
        end
        error
      end

      before { allow(test_webhook_integration).to receive(:sleep) }

      it "retries on 500 errors and succeeds" do
        call_count = 0
        allow(svix_client.application).to receive(:create) do
          call_count += 1
          (call_count == 1) ? raise(server_error) : response
        end

        test_webhook_integration.create_app!

        expect(test_webhook_integration.reload.svix_app_id).to eq("app_123")
        expect(test_webhook_integration).to have_received(:elog).with(
          "Svix API error for train #{train.id}, retrying attempt 1", level: :warn
        )
      end

      it "raises WebhookApiError after max retries" do
        allow(svix_client.application).to receive(:create).and_raise(server_error)

        expect {
          test_webhook_integration.create_app!
        }.to raise_error(SvixIntegration::WebhookApiError)

        expect(test_webhook_integration).to have_received(:elog).with(
          "Failed to create Svix app for train #{train.id}: Internal Server Error", level: :error
        )
      end
    end
  end

  describe "#delete_app!" do
    let(:test_webhook_integration) { create(:webhook_integration, train: train, svix_app_id: "app_123", status: :active) }
    let(:svix_client) { instance_double(Svix::Client) }

    before do
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
      allow(Svix::Client).to receive(:new).and_return(svix_client)
      allow(svix_client).to receive(:application).and_return(instance_double(Svix::Application))
      allow(test_webhook_integration).to receive(:elog)
    end

    it "deletes the Svix app and clears integration data" do
      allow(svix_client.application).to receive(:delete).with("app_123")

      test_webhook_integration.delete_app!

      expect(test_webhook_integration.reload.svix_app_id).to be_nil
      expect(test_webhook_integration.svix_app_uid).to be_nil
      expect(test_webhook_integration.svix_app_name).to be_nil
      expect(test_webhook_integration.status).to eq("inactive")
    end

    it "accepts custom app_id parameter" do
      allow(svix_client.application).to receive(:delete).with("custom_app_123")

      test_webhook_integration.delete_app!(app_id: "custom_app_123")

      expect(test_webhook_integration.reload.svix_app_id).to be_nil
      expect(test_webhook_integration.status).to eq("inactive")
    end

    it "returns early if integration is unavailable" do
      test_webhook_integration.update!(status: :inactive, svix_app_id: nil)

      expect(svix_client).not_to have_received(:application)

      test_webhook_integration.delete_app!
    end
  end

  describe "#send_message" do
    let(:payload) { {event_type: "test.event", data: {test: "data"}} }
    let(:svix_client) { instance_double(Svix::Client) }
    let(:message_api) { instance_double(Svix::Message) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
      allow(Svix::Client).to receive(:new).and_return(svix_client)
      allow(svix_client).to receive(:message).and_return(message_api)
      allow(webhook_integration).to receive(:elog)
    end

    it "sends message successfully" do
      response_obj = instance_double(Svix::MessageOut)
      allow(response_obj).to receive(:to_json).and_return("{\"done\":true}")
      allow(message_api).to receive(:create).and_return(response_obj)

      result = webhook_integration.send_message(payload)

      expect(result).to eq({"done" => true})
    end

    it "raises WebhookApiError on failure" do
      error = StandardError.new("Connection failed")
      def error.code
        500
      end
      allow(message_api).to receive(:create).and_raise(error)

      expect {
        webhook_integration.send_message(payload)
      }.to raise_error(SvixIntegration::WebhookApiError)
    end
  end
end
