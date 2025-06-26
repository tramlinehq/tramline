# frozen_string_literal: true

module Installations
  class Google::VertexAi::Api
    SUPPORTED_RESPONSE_TYPES = %w[text json].freeze
    SUPPORTED_LLMS = {
      gemini: Installations::Google::VertexAi::Gemini,
      llama: Installations::Google::VertexAi::Llama
    }.freeze

    attr_reader :project_id, :key_file

    def initialize(project_id, key_file)
      @project_id = project_id
      @key_file = key_file
      @llm_instances = {}
    end

    def ask(prompt, llm: :gemini, response_type: :text)
      raise ArgumentError, "Invalid response_type: #{response_type}" unless SUPPORTED_RESPONSE_TYPES.include?(response_type.to_s)
      raise ArgumentError, "Invalid LLM: #{llm}" unless SUPPORTED_LLMS.include?(llm)

      model_for(llm).generate(prompt, response_type.to_s)
    end

    private

    def model_for(name)
      @llm_instances[name] ||= SUPPORTED_LLMS.fetch(name).new(project_id, key_file)
    end
  end
end
