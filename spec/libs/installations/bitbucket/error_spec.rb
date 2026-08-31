require "rails_helper"

describe Installations::Bitbucket::Error do
  def error_body(message)
    {"error" => {"message" => message}}
  end

  describe "#reason" do
    it "maps the expired combined-message token error to :token_expired so it can be refreshed" do
      error = described_class.new(error_body("Token is invalid, expired, or not supported for this endpoint."))
      expect(error.reason).to eq(:token_expired)
    end

    it "maps the legacy OAuth2 expiry message to :token_expired" do
      error = described_class.new(error_body("OAuth2 access token expired. Use your refresh token to obtain a new access token."))
      expect(error.reason).to eq(:token_expired)
    end

    it "keeps a genuinely invalid (non-expired) token as :unauthorized" do
      error = described_class.new(error_body("Token is invalid or not supported for this endpoint."))
      expect(error.reason).to eq(:unauthorized)
    end

    it "falls back to :unknown_failure for unrecognized messages" do
      error = described_class.new(error_body("Something else entirely went wrong."))
      expect(error.reason).to eq(:unknown_failure)
    end
  end
end
