module Installations
  class Teamcity::Error < Installations::Error
    # Only errors that are KNOWN to be permanent (no point retrying).
    # Everything else is retryable by default — TeamCity's VCS polling lag
    # can cause many different 4xx responses that resolve on their own.
    NON_RETRYABLE_ERRORS = [
      {
        status: 401,
        decorated_reason: :unauthorized
      },
      {
        status: 403,
        decorated_reason: :forbidden
      }
    ]

    attr_reader :status_code

    def initialize(status_code, response_body)
      @status_code = status_code
      @response_body = response_body
      log
      super(error_message || "TeamCity error (HTTP #{status_code})", reason: handle)
    end

    private

    attr_reader :response_body
    delegate :logger, to: Rails

    def handle
      if non_retryable_match
        non_retryable_match[:decorated_reason]
      else
        :generic_client_error
      end
    end

    def non_retryable_match
      @non_retryable_match ||= NON_RETRYABLE_ERRORS.find { |known_error| known_error[:status] == status_code }
    end

    def error_message
      case response_body
      when Hash
        response_body["message"]
      when String
        response_body.presence
      end
    end

    def log
      logger.error(error_message: error_message, error_body: response_body, status_code: status_code)
    end
  end
end
