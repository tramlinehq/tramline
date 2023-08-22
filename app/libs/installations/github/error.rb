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
        message_matcher: /event cannot have more than 20 hooks/,
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
      },
    ]

    MESSAGES = [
      {
        message_matcher: /Not Found/i,
        decorated_exception: Installations::Errors::ResourceNotFound
      },
      {
        message_matcher: /Reference already exists/,
        decorated_exception: Installations::Errors::TagReferenceAlreadyExists
      },
      {
        message_matcher: /Pull Request is not mergeable/i,
        decorated_exception: Installations::Errors::PullRequestNotMergeable
      },
      {
        message_matcher: /At least 1 approving review is required by reviewers/i,
        decorated_exception: Installations::Errors::PullRequestNotMergeable
      }
    ]

    def self.handle(exception)
      Rails.logger.error(exception)
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
        resource = known_error[:resource]
        code = known_error[:code]
        message_matcher = known_error[:message_matcher]

        errors&.any? do |err|
          resource_match = err["resource"].eql?(resource)
          code_match = err["code"].eql?(code)
          msg_match = message_matcher.nil? ? true : err["message"] =~ message_matcher

          resource_match && code_match && msg_match
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
