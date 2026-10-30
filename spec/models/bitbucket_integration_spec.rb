require "rails_helper"

describe BitbucketIntegration do
  let(:app) { create(:app, :android) }
  let(:integration) { create(:integration, integrable: app) }
  let(:bitbucket_integration) { create(:bitbucket_integration, :without_callbacks_and_validations, integration:) }

  describe "#complete_access" do
    let(:fresh_tokens) { OpenStruct.new(access_token: "fresh_access", refresh_token: "fresh_refresh") }
    let(:reauth_integration) do
      create(:integration, :with_bitbucket, integrable: app).tap(&:mark_needs_reauth!)
    end

    def reauthorize(integration_id, code:)
      Integration.find(integration_id).tap do |reloaded|
        allow(reloaded.providable).to receive(:redirect_uri).and_return("redirect_uri")
        reloaded.providable.assign_attributes(code:)
        reloaded.status = Integration::DEFAULT_CONNECT_STATUS
      end
    end

    it "exchanges a new code for tokens when re-authorizing an existing integration" do
      allow(Installations::Bitbucket::Api).to receive(:oauth_access_token).with("new_code", "redirect_uri").and_return(fresh_tokens)
      reloaded = reauthorize(reauth_integration.id, code: "new_code")

      expect(reloaded.save).to be(true)

      providable = reloaded.providable.reload
      expect(providable.oauth_access_token).to eq("fresh_access")
      expect(providable.oauth_refresh_token).to eq("fresh_refresh")
      expect(reloaded.reload).to be_connected
    end

    it "keeps the integration needing re-authorization when the code exchange returns no tokens" do
      allow(Installations::Bitbucket::Api).to receive(:oauth_access_token).and_return(OpenStruct.new)
      old_access_token = reauth_integration.providable.oauth_access_token
      reloaded = reauthorize(reauth_integration.id, code: "expired_code")

      expect(reloaded.save).to be(false)
      expect(reloaded.providable.reload.oauth_access_token).to eq(old_access_token)
      expect(Integration.find(reauth_integration.id)).to be_needs_reauth
    end

    it "does not call bitbucket when saving without a code" do
      allow(Installations::Bitbucket::Api).to receive(:oauth_access_token)

      described_class.find(bitbucket_integration.id).update!(workspace: "tramline")

      expect(Installations::Bitbucket::Api).not_to have_received(:oauth_access_token)
    end
  end

  describe "#reset_tokens! (private)" do
    let(:valid_tokens) { OpenStruct.new(access_token: "new_access", refresh_token: "new_refresh") }

    before do
      allow(bitbucket_integration).to receive(:redirect_uri).and_return("redirect_uri")
    end

    it "stores the refreshed tokens on itself only" do
      sibling = create(:integration, :with_bitbucket, integrable: app).providable
      sibling_access_token = sibling.oauth_access_token
      allow(Installations::Bitbucket::Api).to receive(:oauth_refresh_token).and_return(valid_tokens)

      bitbucket_integration.send(:reset_tokens!)

      expect(bitbucket_integration.oauth_access_token).to eq("new_access")
      expect(bitbucket_integration.oauth_refresh_token).to eq("new_refresh")
      expect(sibling.reload.oauth_access_token).to eq(sibling_access_token)
    end

    context "when token refresh fails" do
      before do
        allow(integration).to receive(:mark_needs_reauth!)
      end

      {
        "response is nil" => nil,
        "access token is missing" => OpenStruct.new(access_token: "", refresh_token: "refresh"),
        "refresh token is missing" => OpenStruct.new(access_token: "access", refresh_token: "")
      }.each do |case_name, invalid_tokens|
        it "marks integration as needs_reauth when #{case_name}" do
          allow(Installations::Bitbucket::Api).to receive(:oauth_refresh_token).and_return(invalid_tokens)

          expect {
            bitbucket_integration.send(:reset_tokens!)
          }.to raise_error(Installations::Error::TokenRefreshFailure)

          expect(integration).to have_received(:mark_needs_reauth!)
        end
      end
    end
  end

  describe "#with_api_retries (private)" do
    context "when token expires" do
      let(:error) { Installations::Error.new("Token expired", reason: :token_expired) }

      it "resets tokens and retries" do
        call_count = 0
        allow(bitbucket_integration).to receive(:reset_tokens!)

        result = bitbucket_integration.send(:with_api_retries) do
          call_count += 1
          raise error if call_count == 1
          "success"
        end

        expect(result).to eq("success")
        expect(bitbucket_integration).to have_received(:reset_tokens!).once
      end
    end
  end
end
