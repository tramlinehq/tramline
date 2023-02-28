module Installations
  class Apple::AppStoreConnect::Error
    ERRORS = [
      {
        resource: "PullRequest",
        code: "custom",
        message_matcher: /No commits between/,
        decorated_exception: Installations::Errors::PullRequestWithoutCommits
      },
    ]

    def self.handle(response_body)
      new(response_body).handle
    end

    def initialize(response_body)
      @response_body = response_body
    end

    alias_method :body, :response_body

    def handle
      return exception if match.nil?
      match[:decorated_exception].new
    end

    private

    attr_reader :exception

    def match
      @match ||= matched_error
    end

    def matched_error
      ERRORS.find do |known_error|
        error["resource"].eql?(known_error[:resource]) &&
          error["code"].eql?(known_error[:code])
      end
    end

    def error
      body["error"]
    end
  end
end
