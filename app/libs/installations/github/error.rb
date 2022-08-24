module Installations
  class Github::Error
    class UnsupportedType < ArgumentError; end

    class ReferenceAlreadyExists < Octokit::UnprocessableEntity; end

    class NoCommitsForPullRequestError < Octokit::UnprocessableEntity; end

    ERRORS = [
      {
        resource: "PullRequest",
        code: "custom",
        message_matcher: /No commits between/,
        decorated_exception: NoCommitsForPullRequestError
      }
    ]

    MESSAGES = [
      {
        message_matcher: /Reference already exists/,
        decorated_exception: ReferenceAlreadyExists
      }
    ]

    def self.handle(type, exception)
      new(type, exception).handle
    end

    def initialize(type, exception)
      @type = type
      @exception = exception
    end

    def handle
      case type
      when :validation
        handle_validation_errors
      else
        raise UnsupportedType
      end
    end

    def handle_validation_errors
      return exception if match.nil?
      match[:decorated_exception]
    end

    private

    attr_reader :type, :exception

    def match
      @match ||= matched_error || matched_message
    end

    def matched_error
      ERRORS.find do |known_error|
        errors&.any? do |err|
          err["resource"].eql?(known_error[:resource]) &&
            err["code"].eql?(known_error[:code]) &&
            err["message"] =~ known_error[:message_matcher]
        end
      end
    end

    def matched_message
      MESSAGES.find { |known_error_message| known_error_message[:message_matcher] =~ message }
    end

    def body
      @body ||= JSON.parse(exception.response_body)
    end

    def errors
      body["errors"]
    end

    def message
      body["message"]
    end
  end
end
