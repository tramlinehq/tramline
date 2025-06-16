require "rails_helper"

describe Installations::Google::VertexAi::Llama, type: :integration do
  let(:key_file) { File.open("spec/fixtures/google/vertex_ai/service_account.json") }
  let(:llama_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/llama_response.json")) }
  let(:project_id) { "test-1234" }
  let(:prompt) { "What is the capital of France?" }

  describe "#generate" do
    it "returns text response" do
      stub_vertex_ai_llama_api(project_id, prompt, llama_text_response)
      stub_google_service_account_auth

      api = described_class.new(project_id, key_file)

      response = api.generate(prompt)
      expect(response).to eq("The capital of France is Paris.")
    end

    it "raises an error for an invalid response type" do
      expect {
        described_class.new(project_id, key_file, "invalid_response_type")
      }.to raise_error(ArgumentError, /Invalid response_type: invalid_response_type/)
    end
  end
end
