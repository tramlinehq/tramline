module Installations
  class Google::VertexAi::Gemini < Google::VertexAi::Base
    SUPPORTED_RESPONSE_TYPES = %w[text json].freeze
    LOCATION = "us-central1"
    ENDPOINT_URL = Addressable::Template.new(
      "https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/publishers/google/models/{model}:generateContent"
    )

    attr_reader :key_file, :response_type, :project_id

    def initialize(project_id, key_file, response_type = "text")
      raise ArgumentError, "Invalid response_type: #{response_type}" unless SUPPORTED_RESPONSE_TYPES.include?(response_type)

      @key_file = key_file
      @project_id = project_id
      @response_type = response_type
    end

    def generate(prompt)
      perform_request(prompt)
    end

    private

    def perform_request(prompt)
      response = HTTP
        .auth("Bearer #{access_token}")
        .headers("Content-Type" => "application/json")
        .post(ENDPOINT_URL.expand(
          location: LOCATION,
          project_id: project_id,
          model:
        ).to_s, json: request_body(prompt))

      raise Installations::Google::VertexAi::Error.new(JSON.parse(response)) unless response.status.success?

      format_response(JSON.parse(response.body))
    end

    def request_body(prompt)
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
      "gemini-2.5-flash-preview-05-20"
    end

    def format_response(response_json)
      result = response_json["candidates"]&.first&.dig("content", "parts")&.first&.dig("text")
      (response_type == "json") ? JSON.parse(result) : result
    end
  end
end
