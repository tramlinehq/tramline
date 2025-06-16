module Installations
  class Google::VertexAi::Base
    include Google::VertexAi::Auth

    def generate(prompt)
      raise NotImplementedError, "Subclasses must implement generate"
    end
  end
end
