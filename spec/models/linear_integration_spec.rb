require "rails_helper"

RSpec.describe LinearIntegration do
  let(:linear_integration) { build(:linear_integration) }

  describe "validations" do
    it "validates presence of organization_id" do
      linear_integration.organization_id = nil
      expect(linear_integration).not_to be_valid
      expect(linear_integration.errors[:organization_id]).to include("can't be blank")
    end
  end

  describe "#install_path" do
    let(:integration) { build(:integration, :linear, integrable: build(:app)) }
    let(:linear_integration) { integration.providable }

    before do
      linear_integration.integration = integration
      allow(linear_integration).to receive_messages(creds: double(integrations: double(linear: double(client_id: "test_client_id"))), redirect_uri: "http://test.com/callback") # rubocop:disable RSpec/VerifiedDoubles
      allow(integration).to receive(:installation_state).and_return("test_state")
    end

    it "returns the correct OAuth URL" do
      expect(linear_integration.install_path).to include("https://linear.app/oauth/authorize")
      expect(linear_integration.install_path).to include("client_id=test_client_id")
      expect(linear_integration.install_path).to include("redirect_uri=http%3A%2F%2Ftest.com%2Fcallback")
      expect(linear_integration.install_path).to include("state=test_state")
    end
  end

  describe "#complete_access" do
    let(:integration) { build(:integration, :linear, integrable: build(:app)) }
    let(:linear_integration) { integration.providable }

    before do
      allow(linear_integration).to receive(:redirect_uri).and_return("http://test.com/callback")
    end

    context "when code is blank" do
      it "returns false" do
        linear_integration.code = nil
        expect(linear_integration.complete_access).to be false
      end
    end

    context "when organization_id is already set" do
      it "returns true" do
        linear_integration.code = "test_code"
        linear_integration.organization_id = "existing_org_id"

        allow(Installations::Linear::Api).to receive(:get_access_token).and_return(
          double(access_token: "token", refresh_token: "refresh")
        )

        expect(linear_integration.complete_access).to be true
      end
    end
  end

  describe "#display" do
    it "returns 'Linear'" do
      expect(linear_integration.display).to eq("Linear")
    end
  end

  describe "#to_s" do
    it "returns 'linear'" do
      expect(linear_integration.to_s).to eq("linear")
    end
  end

  describe "#further_setup?" do
    it "returns true" do
      expect(linear_integration.further_setup?).to be true
    end
  end

  describe "#connectable?" do
    it "returns true" do
      expect(linear_integration.connectable?).to be true
    end
  end

  describe "#creatable?" do
    it "returns false" do
      expect(linear_integration.creatable?).to be false
    end
  end

  describe "#store?" do
    it "returns false" do
      expect(linear_integration.store?).to be false
    end
  end
end
