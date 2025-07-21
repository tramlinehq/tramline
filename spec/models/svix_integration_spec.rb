require "rails_helper"

describe SvixIntegration do
  let(:train) { create(:train, :with_no_platforms) }
  let(:svix_integration) { create(:svix_integration, train: train) }

  describe "associations" do
    it "belongs to train" do
      expect(svix_integration.train).to eq(train)
    end
  end

  describe "validations" do
    it "validates presence of status" do
      svix_integration.status = nil
      expect(svix_integration).not_to be_valid
      expect(svix_integration.errors[:status]).to include("can't be blank")
    end

    it "validates uniqueness of app_id" do
      create(:svix_integration, app_id: "duplicate_id", train: train)
      new_integration = build(:svix_integration, app_id: "duplicate_id", train: create(:train, :with_no_platforms))
      expect(new_integration).not_to be_valid
      expect(new_integration.errors[:app_id]).to include("has already been taken")
    end

    it "allows nil app_id" do
      svix_integration.app_id = nil
      expect(svix_integration).to be_valid
    end
  end

  describe "enums" do
    it "defines status enum with correct values" do
      expect(described_class.statuses).to eq({"active" => "active", "inactive" => "inactive"})
    end
  end

  describe "#create_svix_app!" do
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

      test_svix_integration = create(:svix_integration, train: train, app_id: nil)

      test_svix_integration.create_svix_app!

      expect(test_svix_integration.reload.app_id).to eq("app_123")
      expect(test_svix_integration.status).to eq("active")
    end
  end

  describe "#create_endpoint" do
    it "creates an endpoint for the Svix app" do
      svix_client = instance_double(Svix::Client)
      endpoint_api = instance_double(Svix::Endpoint)
      endpoint_in = instance_double(Svix::EndpointIn)

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SVIX_TOKEN").and_return("test_token")
      allow(Svix::Client).to receive(:new).with("test_token").and_return(svix_client)
      allow(Svix::EndpointIn).to receive(:new).and_return(endpoint_in)
      allow(svix_client).to receive(:endpoint).and_return(endpoint_api)
      allow(endpoint_api).to receive(:create).with(svix_integration.app_id, endpoint_in)

      svix_integration.create_endpoint("https://example.com/webhook")

      expect(endpoint_api).to have_received(:create).with(svix_integration.app_id, endpoint_in)
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
      allow(message_api).to receive(:create).with(svix_integration.app_id, message_in)

      svix_integration.send_message(payload)

      expect(message_api).to have_received(:create).with(svix_integration.app_id, message_in)
    end
  end
end
