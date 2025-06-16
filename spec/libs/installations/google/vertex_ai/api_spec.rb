require "rails_helper"

describe Installations::Google::VertexAi::Api, type: :integration do
  let(:key_file) { File.open("spec/fixtures/google/vertex_ai/service_account.json") }
  let(:gemini_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/gemini_response.json")) }
  let(:project_id) { "test-1234" }
  let(:prompt) { "What is the capital of France?" }

  describe "#process" do
    it "inject LLM instance and returns its response" do
      stub_vertex_ai_gemini_api(project_id, prompt, gemini_text_response)
      stub_google_service_account_auth

      llm = Installations::Google::VertexAi::Gemini.new(project_id, key_file)
      response = described_class.new(llm).process(prompt)

      expect(response).to eq("The capital of France is Paris.")
    end
  end
end
