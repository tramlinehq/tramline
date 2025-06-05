require "rails_helper"

describe Installations::Google::VertexAi::Api, type: :integration do
  let(:key_file) { File.open("spec/fixtures/google/vertex_ai/service_account.json") }
  let(:gemini_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/gemini_response.json")) }
  let(:gemini_json_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/gemini_json_response.json")) }
  let(:llama_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/llama_response.json")) }
  let(:project_id) { "test-1234" }
  let(:prompt) { "What is the capital of France?" }

  describe "#generate" do
    it "returns text response by gemini" do
      stub_vertex_ai_gemini_api(project_id, prompt, gemini_text_response)
      stub_google_service_account_auth
      api = described_class.new(project_id, prompt, "gemini", key_file)

      response = api.generate
      expect(response).to eq("The capital of France is Paris.")
    end

    it "returns json response by gemini" do
      stub_vertex_ai_gemini_api(project_id, json_prompt, gemini_json_response, "json")
      stub_google_service_account_auth
      api = described_class.new(project_id, json_prompt, "gemini", key_file, "json")

      response = api.generate
      expect(response).to eq(json_response)
    end

    it "returns text response by llama" do
      stub_vertex_ai_llama_api(project_id, prompt, llama_text_response)
      stub_google_service_account_auth

      api = described_class.new(project_id, prompt, "llama", key_file)

      response = api.generate
      expect(response).to eq("The capital of France is Paris.")
    end

    it "raises an error for an invalid model" do
      expect {
        described_class.new(project_id, prompt, "invalid_model", key_file)
      }.to raise_error(ArgumentError, /Invalid model: invalid_model/)
    end

    it "raises an error for an invalid response type" do
      expect {
        described_class.new(project_id, prompt, "gemini", key_file, "invalid_response_type")
      }.to raise_error(ArgumentError, /Invalid response_type: invalid_response_type/)
    end
  end

  private

  def json_response
    {"planet" => "Earth",
     "continents" => ["Africa", "Asia", "Europe", "North America", "South America", "Australia", "Antarctica"],
     "oceans" => {"largest" => "Pacific", "smallest" => "Arctic"}}
  end

  def json_prompt
    "Give me a JSON object containing:
    - the name of the planet Earth,
    - a list of its continents,
    - and a nested object of oceans where the largest is the Pacific and the smallest is the Arctic."
  end
end
