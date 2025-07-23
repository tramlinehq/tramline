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
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
    end

    it "creates a Svix app and updates the integration" do
      svix_client = instance_double(Svix::Client)
      application_api = instance_double(Svix::Application)
      application_in = instance_double(Svix::ApplicationIn)
      response = instance_double(Svix::ApplicationOut, id: "app_123")

      allow(Svix::Client).to receive(:new).with("test_token").and_return(svix_client)
      allow(Svix::ApplicationIn).to receive(:new).and_return(application_in)
      allow(svix_client).to receive(:application).and_return(application_api)
      allow(application_api).to receive(:create).with(application_in).and_return(response)

      test_webhook_integration = create(:webhook_integration, train: train, svix_app_id: nil)

      test_webhook_integration.create_app!

      expect(test_webhook_integration.reload.svix_app_id).to eq("app_123")
      expect(test_webhook_integration.status).to eq("active")
    end

    it "logs error and re-raises when Svix API fails" do
      svix_client = instance_double(Svix::Client)
      application_api = instance_double(Svix::Application)
      application_in = instance_double(Svix::ApplicationIn)

      allow(Svix::Client).to receive(:new).with("test_token").and_return(svix_client)
      allow(Svix::ApplicationIn).to receive(:new).and_return(application_in)
      allow(svix_client).to receive(:application).and_return(application_api)
      allow(application_api).to receive(:create).and_raise(StandardError.new("API Error"))

      test_webhook_integration = create(:webhook_integration, train: train, svix_app_id: nil)

      allow(test_webhook_integration).to receive(:elog)

      expect {
        test_webhook_integration.create_app!
      }.to raise_error(StandardError, "API Error")

      expect(test_webhook_integration).to have_received(:elog).with(
        "Failed to create Svix app for train #{train.id}: API Error",
        level: :warn
      )
    end
  end

  describe "#send_message" do
    it "sends a message through Svix" do
      svix_client = instance_double(Svix::Client)
      message_api = instance_double(Svix::Message)
      message_in = instance_double(Svix::MessageIn)
      payload = {event_type: "test.event", data: {test: "data"}}

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
      allow(Svix::Client).to receive(:new).with("test_token").and_return(svix_client)
      allow(Svix::MessageIn).to receive(:new).and_return(message_in)
      allow(svix_client).to receive(:message).and_return(message_api)
      allow(message_api).to receive(:create).with(webhook_integration.svix_app_id, message_in).and_return("{\"done\":true}")

      webhook_integration.send_message(payload)

      expect(message_api).to have_received(:create).with(webhook_integration.svix_app_id, message_in)
    end

    it "logs error and re-raises when message sending fails" do
      svix_client = instance_double(Svix::Client)
      message_api = instance_double(Svix::Message)
      message_in = instance_double(Svix::MessageIn)
      payload = {event_type: "test.event", data: {test: "data"}}

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
      allow(Svix::Client).to receive(:new).with("test_token").and_return(svix_client)
      allow(Svix::MessageIn).to receive(:new).and_return(message_in)
      allow(svix_client).to receive(:message).and_return(message_api)
      allow(message_api).to receive(:create).and_raise(Faraday::Error.new("Connection failed"))

      allow(webhook_integration).to receive(:elog)

      expect {
        webhook_integration.send_message(payload)
      }.to raise_error(Faraday::Error, "Connection failed")

      expect(webhook_integration).to have_received(:elog).with(
        "Failed to send Svix message for app #{webhook_integration.svix_app_id}: Connection failed",
        level: :warn
      )
    end
  end
end
