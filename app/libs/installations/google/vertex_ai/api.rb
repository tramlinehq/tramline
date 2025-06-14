# frozen_string_literal: true

module Installations
  class Google::VertexAi::Api
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = "https://www.googleapis.com/auth/cloud-platform"
    SUPPORTED_MODELS = {
      gemini: "gemini-2.5-flash-preview-05-20",
      llama: "meta/llama-4-maverick-17b-128e-instruct-maas"
    }.freeze
    SUPPORTED_RESPONSE_TYPES = %w[text json].freeze

    attr_reader :key_file, :prompt, :model, :response_type, :project_id

    def initialize(project_id, prompt, model, key_file, response_type = "text")
      raise ArgumentError, "Invalid response_type: #{response_type}" unless SUPPORTED_RESPONSE_TYPES.include?(response_type)
      raise ArgumentError, "Invalid model: #{model}" unless SUPPORTED_MODELS.key?(model.to_sym)

      @project_id = project_id
      @key_file = key_file
      @prompt = prompt
      @model = model
      @response_type = response_type
    end

    def generate
      case model
      when "gemini"
        Google::VertexAi::Gemini.new(project_id, prompt, model, key_file, response_type).generate
      when "llama"
        Google::VertexAi::Llama.new(project_id, prompt, key_file, response_type).generate
      end
    end

    private

    def access_token
      auth_client.fetch_access_token!["access_token"]
    end

    def auth_client
      key_file.rewind
      SERVICE_ACCOUNT.make_creds(json_key_io: key_file, scope: SCOPE)
    end
  end
end
