module Installations
  class Bitbucket::Error < Installations::Error
    ERRORS = [
      {
        message_matcher: /Token is invalid or not supported for this endpoint/i,
        decorated_reason: :unauthorized
      },
      {
        message_matcher: /OAuth2 access token expired. Use your refresh token to obtain a new access token/i,
        decorated_reason: :token_expired
      },
      {
        message_matcher: /is not a valid hook/i,
        decorated_reason: :webhook_not_found
      },
      {
        message_matcher: /tag .* already exists/i,
        decorated_reason: :tag_reference_already_exists
      },
      {
        message_matcher: /You can't merge until you resolve all merge conflicts/i,
        decorated_reason: :pull_request_not_mergeable
      },
      {
        message_matcher: /failed merge checks/i,
        decorated_reason: :pull_request_not_mergeable
      }
    ]

    def initialize(error_body)
      @error_body = error_body
      log
      super(error_message, reason: handle)
    end

    def handle
      return :unknown_failure if match.nil?
      match[:decorated_reason]
    end

    private

    attr_reader :error_body
    delegate :logger, to: Rails

    def match
      @match ||= matched_error
    end

    def matched_error
      ERRORS.find do |known_error|
        known_error[:message_matcher] =~ error_message
      end
    end

    def error_message
      error_body.dig("error", "message")
    end

    def log
      logger.error(error_message: error_message, error_body: error_body)
    end
  end
end
