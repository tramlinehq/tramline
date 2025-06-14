module Installations
  class Google::VertexAi::Gemini < Google::VertexAi::Api
    LOCATION = "us-central1"
    ENDPOINT_URL = Addressable::Template.new(
      "https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/publishers/google/models/{model}:generateContent"
    )

    attr_reader :key_file, :prompt, :response_type, :project_id

    def initialize(project_id, prompt, key_file, response_type)
      @project_id = project_id
      @key_file = key_file
      @prompt = prompt
      @response_type = response_type
    end

    def generate
      perform_request
    end

    private

    def perform_request
      response = HTTP
        .auth("Bearer #{access_token}")
        .headers("Content-Type" => "application/json")
        .post(ENDPOINT_URL.expand(
          location: LOCATION,
          project_id: project_id,
          model: model
        ).to_s, json: request_body)

      raise Installations::Google::VertexAi::Error.new(JSON.parse(response)) unless response.status.success?

      format_response(JSON.parse(response.body))
    end

    def request_body
      body = {
        contents: [
          {
            role: "user",
            parts: [
              {text: prompt}
            ]
          }
        ]
      }

      if response_type == "json"
        body[:generationConfig] = {responseMimeType: "application/json"}
      end

      body
    end

    def model
      SUPPORTED_MODELS[:gemini]
    end

    def format_response(response_json)
      result = response_json["candidates"]&.first&.dig("content", "parts")&.first&.dig("text")
      (response_type == "json") ? JSON.parse(result) : result
    end
  end
end
