module Installations
  class Gitlab::Error < Installations::Error
    ERRORS = [
      {
        error: "invalid_token",
        decorated_reason: :token_expired
      }
    ]

    MESSAGES = [
      {
        message_matcher: /Another open merge request already exists for this source branch/,
        decorated_reason: :pull_request_already_exists
      },
      {
        message_matcher: /The merge request failed to merge/,
        decorated_reason: :pull_request_not_mergeable
      },
      {
        message_matcher: /The merge request is not able to be merged/,
        decorated_reason: :pull_request_not_mergeable
      },
      {
        message_matcher: /Tag (.*) already exists/,
        decorated_reason: :tag_reference_already_exists
      },
      {
        message_matcher: /Release already exists/,
        decorated_reason: :tagged_release_already_exists
      },
      {
        message_matcher: /Not found/i,
        decorated_reason: :not_found
      },
      {
        message_matcher: /Branch cannot be merged/i,
        decorated_reason: :pull_request_not_mergeable
      },
      {
        message_matcher: /open merge request already exists/i,
        decorated_reason: :pull_request_already_exists
      },
      # NOTE: This is a temporary solution till GitLab starts sending correct message for the merge failure
      # See: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/115088
      {
        message_matcher: /405 Method Not Allowed/i,
        decorated_reason: :pull_request_not_mergeable
      },
      {
        message_matcher: /404 File Not Found/i,
        decorated_reason: :file_not_found
      },
      {
        message_matcher: /Unplayable Job/,
        decorated_reason: :workflow_run_not_runnable
      }
    ]

    def initialize(response_body)
      Rails.logger.debug { "GitLab error: #{response_body}" }
      @response_body = response_body
      super(error_message, reason: handle)
    end

    def handle
      return :unknown_failure if match.nil?
      match[:decorated_reason]
    end

    private

    attr_reader :response_body
    alias_method :body, :response_body

    def match
      @match ||= matched_error || matched_message
    end

    def matched_message
      MESSAGES.find { |known_error_message| known_error_message[:message_matcher] =~ error_message }
    end

    def matched_error
      ERRORS.find { |known_error| known_error[:error].eql?(error) }
    end

    def error
      body["error"]
    end

    def error_message
      [*body["message"]].first
    end
  end
end
