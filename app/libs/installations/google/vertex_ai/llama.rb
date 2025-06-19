module Installations
  class Google::VertexAi::Llama
    include Google::VertexAi::Auth

    LOCATION = "us-east5"
    ENDPOINT_URL = Addressable::Template.new(
      "https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/endpoints/openapi/chat/completions"
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
          project_id: project_id
        ).to_s, json: request_body(prompt, response_type))

      raise Installations::Google::VertexAi::Error.new(JSON.parse(response)) unless response.status.success?

      parse_response(JSON.parse(response.body), response_type)
    end

    def request_body(prompt, response_type)
      {
        model: model,
        stream: false,
        messages: [
          {
            role: "user",
            content: (response_type == "json") ? formatted_json_prompt(prompt) : prompt
          }
        ]
      }
    end

    def formatted_json_prompt(prompt)
      <<~PROMPT.strip
        #{prompt}

        Please respond with a **raw JSON object** only.
        Do **not** include any markdown formatting, code block fences (like ```json), or explanations.
      PROMPT
    end

    def model
      "meta/llama-4-maverick-17b-128e-instruct-maas"
    end

    def parse_response(data, response_type)
      result = data.dig("choices", 0, "message", "content")
      (response_type == "json") ? JSON.parse(result) : result
    end
  end
end
