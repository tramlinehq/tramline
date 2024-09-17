module Installations
  class Google::Firebase::Error < Installations::Error
    using RefinedString

    ERRORS = [
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /Project .* has been deleted/,
        decorated_reason: :permission_denied
      },
      {
        status: "INVALID_ARGUMENT",
        code: 400,
        message_matcher: /Request contains an invalid argument/,
        decorated_reason: :invalid_config
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /The caller does not have permission/,
        decorated_reason: :permission_denied
      },
      {
        status: "NOT_FOUND",
        code: 404,
        message_matcher: /Requested entity was not found/i,
        decorated_reason: :not_found
      }
    ]

    def self.reasons
      ERRORS.pluck(:decorated_reason).uniq.map(&:to_s)
    end

    def initialize(api_error)
      @api_error = api_error
      log
      super(error_message, reason: handle)
    end

    def handle
      return :unknown_failure if match.nil?
      match[:decorated_reason]
    end

    private

    attr_reader :api_error
    delegate :logger, to: Rails

    def match
      @match ||= matched_error
    end

    def matched_error
      ERRORS.find do |known_error|
        known_error[:status].eql?(status) &&
          known_error[:code].eql?(code) &&
          known_error[:message_matcher] =~ error_message
      end
    end

    def parsed_body
      @parsed_body ||= api_error&.body&.safe_json_parse
    end

    def error_body
      return api_error.body if parsed_body.blank?
      parsed_body["error"]
    end

    def error_message
      error_body["message"]
    end

    def code
      error_body["code"]
    end

    def status
      error_body["status"]
    end

    def log
      logger.error(api_error)
    end
  end
end
