module Installations
  class Google::VertexAi::Llama < Google::VertexAi::Api
    extend Forwardable

    LOCATION = "us-east5"
    ENDPOINT_URL = Addressable::Template.new(
      "https://{location}-aiplatform.googleapis.com/v1/projects/{project_id}/locations/{location}/endpoints/openapi/chat/completions"
    )

    attr_reader :api
    def_delegators :api, :key_file, :prompt, :response_type, :project_id

    def initialize(api)
      @api = api
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
          project_id: project_id
        ).to_s, json: request_body)

      unless response.status.success?
        raise Installations::Google::VertexAi::Error.new(JSON.parse(response))
      end

      parse_response(JSON.parse(response.body))
    end

    def request_body
      {
        model: model,
        stream: false,
        messages: [
          {
            role: "user",
            content: (response_type == "json") ? formatted_json_prompt : prompt
          }
        ]
      }
    end

    def formatted_json_prompt
      <<~PROMPT.strip
        #{prompt}

        Please respond with a **raw JSON object** only.
        Do **not** include any markdown formatting, code block fences (like ```json), or explanations.
      PROMPT
    end

    def model
      SUPPORTED_MODELS[:llama]
    end

    def parse_response(data)
      result = data.dig("choices", 0, "message", "content")
      (response_type == "json") ? JSON.parse(result) : result
    end
  end
end
