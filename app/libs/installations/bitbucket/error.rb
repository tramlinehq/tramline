module Installations
  class Bitbucket::Error < Installations::Error
    using RefinedString

    ERRORS = [
      {
        message_matcher: /Token is invalid or not supported for this endpoint/i,
        decorated_reason: :unauthorized
      },
      {
        message_matcher: /OAuth2 access token expired. Use your refresh token to obtain a new access token/i,
        decorated_reason: :token_expired
      }
    ]

    def self.reasons
      ERRORS.pluck(:decorated_reason).uniq.map(&:to_s)
    end

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
      logger.error(error_message, error_body)
    end
  end
end
