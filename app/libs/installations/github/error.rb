module Installations
  class Github::Error
    class UnsupportedType < ArgumentError; end

    class NoCommitsForPullRequestError < Octokit::UnprocessableEntity; end

    ERRORS = [
      {
        resource: "PullRequest",
        code: "custom",
        message_matcher: /No commits between/,
        decorated_exception: NoCommitsForPullRequestError
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
      return exception if matched_error.nil?
      matched_error[:decorated_exception]
    end

    private

    attr_reader :type, :exception

    def matched_error
      @matched_error ||=
        ERRORS.find do |known_error|
          errors.any? do |err|
            err["resource"].eql?(known_error[:resource]) &&
              err["code"].eql?(known_error[:code]) &&
              err["message"] =~ known_error[:message_matcher]
          end
        end
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
