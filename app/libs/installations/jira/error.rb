module Installations
  class Jira::Error < Installations::Error
    ERRORS = [
      {
        message_matcher: /The access token expired/i,
        decorated_reason: :token_expired
      },
      {
        message_matcher: /does not have the required scope/i,
        decorated_reason: :insufficient_scope
      },
      {
        message_matcher: /Project .* does not exist/i,
        decorated_reason: :project_not_found
      },
      {
        message_matcher: /Issue does not exist/i,
        decorated_reason: :issue_not_found
      },
      {
        message_matcher: /Service Unavailable/i,
        decorated_reason: :service_unavailable
      }
    ].freeze

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
