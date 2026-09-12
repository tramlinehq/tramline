require "rails_helper"

describe BitbucketIntegration do
  let(:app) { create(:app, :android) }
  let(:integration) { create(:integration, integrable: app) }
  let(:bitbucket_integration) { create(:bitbucket_integration, :without_callbacks_and_validations, integration:) }

  describe "#reset_tokens! (private)" do
    let(:valid_tokens) { OpenStruct.new(access_token: "new_access", refresh_token: "new_refresh") }

    before do
      allow(bitbucket_integration).to receive_messages(redirect_uri: "redirect_uri", affiliated_providers: [bitbucket_integration])
    end

    context "when successful" do
      before do
        allow(Installations::Bitbucket::Api).to receive(:oauth_refresh_token).and_return(valid_tokens)
        allow(bitbucket_integration).to receive(:set_tokens)
        allow(bitbucket_integration).to receive(:save!)
      end

      it "updates tokens on all affiliated providers" do
        bitbucket_integration.send(:reset_tokens!)

        expect(bitbucket_integration).to have_received(:set_tokens).with(valid_tokens)
        expect(bitbucket_integration).to have_received(:save!)
      end
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
