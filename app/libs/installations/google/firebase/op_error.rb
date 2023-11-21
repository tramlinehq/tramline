module Installations
  class Google::Firebase::OpError < Installations::Error
    using RefinedString

    ERRORS = [
      {
        code: 3,
        message_matcher: /Ensure you are uploading a valid IPA or APK and try again/,
        decorated_reason: :invalid_api_package
      },
      {
        message_matcher: /There was a error processing your app. Try distributing again and contact Firebase support if this problem continues/i,
        decorated_reason: :firebase_processing_error
      }
    ]

    def self.reasons
      ERRORS.pluck(:decorated_reason).uniq.map(&:to_s)
    end

    def initialize(op_error)
      @op_error = op_error
      log
      super(error_message, reason: handle)
    end

    def handle
      return :unknown_failure if match.nil?
      match[:decorated_reason]
    end

    private

    attr_reader :op_error
    delegate :logger, to: Rails

    def match
      @match ||= matched_error
    end

    def matched_error
      ERRORS.find do |known_error|
        known_error[:code].eql?(code) &&
          known_error[:message_matcher] =~ error_message
      end
    end

    def error_message
      op_error[:message]
    end

    def code
      op_error[:code]
    end

    def log
      logger.error(op_error)
    end
  end
end
