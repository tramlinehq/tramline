require "rails_helper"

describe Installations::Teamcity::Error do
  describe "retryable reasons (default)" do
    it "maps 400 errors to :generic_client_error" do
      error = described_class.new(400, {"message" => "Could not find the given change 'abc123' in VCS roots"})

      expect(error.reason).to eq(:generic_client_error)
    end

    it "maps 404 errors to :generic_client_error" do
      error = described_class.new(404, {"message" => "Nothing is found by locator 'count:1,version:abc123'"})

      expect(error.reason).to eq(:generic_client_error)
    end

    it "maps 422 errors to :generic_client_error" do
      error = described_class.new(422, {"message" => "Something unexpected"})

      expect(error.reason).to eq(:generic_client_error)
    end

    it "maps unknown 4xx errors to :generic_client_error" do
      error = described_class.new(409, {"message" => "Conflict"})

      expect(error.reason).to eq(:generic_client_error)
    end
  end

  describe "non-retryable reasons" do
    it "maps 401 to :unauthorized" do
      error = described_class.new(401, {"message" => "Authentication required"})

      expect(error.reason).to eq(:unauthorized)
    end

    it "maps 403 to :forbidden" do
      error = described_class.new(403, {"message" => "Access denied"})

      expect(error.reason).to eq(:forbidden)
    end
  end

  describe "message extraction" do
    it "extracts message from JSON hash body" do
      error = described_class.new(400, {"message" => "Some error"})

      expect(error.message).to eq("Some error")
    end

    it "uses string body directly" do
      error = described_class.new(400, "Plain text error")

      expect(error.message).to eq("Plain text error")
    end

    it "falls back to HTTP status when no message" do
      error = described_class.new(400, {})

      expect(error.message).to eq("TeamCity error (HTTP 400)")
    end
  end

  describe "logging" do
    it "logs the error on construction" do
      allow(Rails.logger).to receive(:error)

      described_class.new(400, {"message" => "Some error"})

      expect(Rails.logger).to have_received(:error).with(hash_including(status_code: 400, error_message: "Some error"))
    end
  end

  describe "inheritance" do
    it "is a subclass of Installations::Error" do
      error = described_class.new(400, {"message" => "test"})

      expect(error).to be_a(Installations::Error)
    end

    it "exposes status_code" do
      error = described_class.new(404, {"message" => "test"})

      expect(error.status_code).to eq(404)
    end
  end
end
