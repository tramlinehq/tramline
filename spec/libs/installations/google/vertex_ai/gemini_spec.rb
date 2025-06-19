require "rails_helper"

describe Installations::Google::VertexAi::Gemini, type: :integration do
  let(:key_file) { File.open("spec/fixtures/google/vertex_ai/service_account.json") }
  let(:gemini_text_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/gemini_response.json")) }
  let(:gemini_json_response) { JSON.parse(File.read("spec/fixtures/google/vertex_ai/gemini_json_response.json")) }
  let(:project_id) { "test-1234" }
  let(:prompt) { "What is the capital of France?" }

  describe "#generate" do
    before do
      stub_google_service_account_auth
    end

    it "returns text response" do
      stub_vertex_ai_gemini_api(project_id, prompt, gemini_text_response)
      api = described_class.new(project_id, key_file)

      response = api.generate(prompt, "text")
      expect(response).to eq("The capital of France is Paris.")
    end

    it "returns json response" do
      stub_vertex_ai_gemini_api(project_id, json_prompt, gemini_json_response, "json")
      api = described_class.new(project_id, key_file)

      response = api.generate(json_prompt, "json")
      expect(response).to eq(json_response)
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
