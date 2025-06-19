require "rails_helper"

describe Installations::Google::VertexAi::Api, type: :integration do
  let(:key_file) { File.open("spec/fixtures/google/vertex_ai/service_account.json") }
  let(:llama_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/llama_response.json")) }
  let(:project_id) { "test-1234" }
  let(:prompt) { "What is the capital of France?" }

  describe "#ask" do
    before do
      stub_google_service_account_auth
    end

    it "return response for the prompt" do
      stub_vertex_ai_llama_api(project_id, prompt, llama_text_response)
      response = described_class.new(project_id, key_file).ask(prompt, llm: :llama)

      expect(response).to eq("The capital of France is Paris.")
    end

    it "raises an error for an invalid response type" do
      expect {
        described_class.new(project_id, key_file).ask(prompt, response_type: :invalid)
      }.to raise_error(ArgumentError, /Invalid response_type: invalid/)
    end

    it "raises an error for an invalid llm" do
      expect {
        described_class.new(project_id, key_file).ask(prompt, llm: :invalid)
      }.to raise_error(ArgumentError, /Invalid LLM: invalid/)
    end
  end
end
