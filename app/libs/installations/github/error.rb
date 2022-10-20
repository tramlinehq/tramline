module Installations
  class Github::Error
    ERRORS = [
      {
        resource: "PullRequest",
        code: "custom",
        message_matcher: /No commits between/,
        decorated_exception: Installations::Errors::PullRequestWithoutCommits
      },
      {
        resource: "PullRequest",
        code: "custom",
        message_matcher: /A pull request already exists for/,
        decorated_exception: Installations::Errors::PullRequestAlreadyExists
      },
      {
        resource: "Hook",
        code: "custom",
        message_matcher: /The "workflow_run" event cannot have more than 20 hooks/,
        decorated_exception: Installations::Errors::WebhookLimitReached
      },
      {
        resource: "Hook",
        code: "custom",
        message_matcher: /Hook already exists on this repository/,
        decorated_exception: Installations::Errors::HookAlreadyExistsOnRepository
      },
      {
        resource: "Release",
        code: "already_exists",
        decorated_exception: Installations::Errors::TaggedReleaseAlreadyExists
      }
    ]

    MESSAGES = [
      {
        message_matcher: /Reference already exists/,
        decorated_exception: Installations::Errors::TagReferenceAlreadyExists
      },
      {
        message_matcher: /Pull Request is not mergeable/,
        decorated_exception: Installations::Errors::PullRequestNotMergeable
      },
      {
        message_matcher: /Not Found/,
        decorated_exception: Installations::Errors::ResourceNotFound
      }
    ]

    def self.handle(exception)
      new(exception).handle
    end

    def initialize(exception)
      @exception = exception
    end

    def handle
      return exception if match.nil?
      match[:decorated_exception].new
    end

    private

    attr_reader :exception

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
