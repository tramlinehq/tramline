module Installations
  class Google::VertexAi::Gemini
    include Google::VertexAi::Auth

    LOCATION = "us-central1"
    ENDPOINT_URL = Addressable::Template.new(
      "https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/publishers/google/models/{model}:generateContent"
    )

    attr_reader :key_file, :project_id

    def initialize(project_id, key_file)
      @project_id = project_id
      @key_file = key_file
    end

    def generate(prompt, response_type)
      perform_request(prompt, response_type)
    end

    private

    def perform_request(prompt, response_type)
      response = HTTP
        .auth("Bearer #{access_token}")
        .headers("Content-Type" => "application/json")
        .post(ENDPOINT_URL.expand(
          location: LOCATION,
          project_id: project_id,
          model: model
        ).to_s, json: request_body(prompt, response_type))

      raise Installations::Google::VertexAi::Error.new(JSON.parse(response)) unless response.status.success?

      format_response(JSON.parse(response.body), response_type)
    end

    def request_body(prompt, response_type)
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
      "gemini-2.5-flash"
    end

    def format_response(response_json, response_type)
      result = response_json["candidates"]&.first&.dig("content", "parts")&.first&.dig("text")
      (response_type == "json") ? JSON.parse(result) : result
    end
  end
end
