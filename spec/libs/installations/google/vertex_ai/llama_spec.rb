require "rails_helper"

describe Installations::Google::VertexAi::Llama, type: :integration do
  let(:key_file) { File.open("spec/fixtures/google/vertex_ai/service_account.json") }
  let(:llama_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/llama_response.json")) }
  let(:project_id) { "test-1234" }
  let(:prompt) { "What is the capital of France?" }

  describe "#generate" do
    before do
      stub_google_service_account_auth
    end

    it "returns text response" do
      stub_vertex_ai_llama_api(project_id, prompt, llama_text_response)
      api = described_class.new(project_id, key_file)

      response = api.generate(prompt, "text")
      expect(response).to eq("The capital of France is Paris.")
    end
  end
end
