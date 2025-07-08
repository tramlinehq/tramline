module Installations
  class Linear::Error < Installations::Error
    def initialize(response_body)
      errors = response_body.dig("errors") || []
      message = errors.pluck("message").join(", ")
      super(message.presence || "Linear API error", reason: :api_error)
    end
  end
end
