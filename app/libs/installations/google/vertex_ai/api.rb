# frozen_string_literal: true

module Installations
  class Google::VertexAi::Api
    attr_reader :llm_instance

    def initialize(llm_instance)
      @llm_instance = llm_instance
    end

    def process(prompt)
      llm_instance.generate(prompt)
    end
  end
end
