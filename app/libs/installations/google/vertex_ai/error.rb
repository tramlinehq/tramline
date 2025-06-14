# frozen_string_literal: true

module Installations
  class Google::VertexAi::Error < Installations::Error
    using RefinedString

    ERRORS = [
      {
        status: "INVALID_ARGUMENT",
        code: 400,
        message_matcher: /Please use a valid role/,
        decorated_reason: :invalid_argument
      },
      {
        status: "INVALID_ARGUMENT",
        code: 400,
        message_matcher: /Malformed publisher model/,
        decorated_reason: :invalid_argument
      },
      {
        status: "NOT_FOUND",
        code: 404,
        message_matcher: /not found/i,
        decorated_reason: :not_found
      },
      {
        status: "RESOURCE_EXHAUSTED",
        code: 429,
        message_matcher: /Quota exceeded/i,
        decorated_reason: :quota_exceeded
      },
      {
        status: "UNAUTHENTICATED",
        code: 401,
        message_matcher: /invalid authentication credentials./i,
        decorated_reason: :unauthenticated
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
      error_body.is_a?(Array) ? error_body[0].dig("error", "message") : error_body.dig("error", "message")
    end

    def log
      logger.error(error_body)
    end
  end
end
