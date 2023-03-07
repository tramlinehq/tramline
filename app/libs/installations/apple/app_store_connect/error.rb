module Installations
  class Apple::AppStoreConnect::Error < Installations::Error
    ERRORS = [
      {
        resource: "app",
        code: "not_found",
        decorated_reason: :app_not_found
      },
      {
        resource: "build",
        code: "not_found",
        decorated_reason: :build_not_found
      },
      {
        resource: "build",
        code: "export_compliance_not_updateable",
        decorated_reason: :missing_export_compliance
      },
      {
        resource: "beta_group",
        code: "not_found",
        decorated_reason: :beta_group_not_found
      },
      {
        resource: "release",
        code: "not_found",
        decorated_reason: :release_not_found
      },
      {
        resource: "release",
        code: "review_submission_not_allowed",
        decorated_reason: :build_not_submittable
      },
      {
        resource: "release",
        code: "build_mismatch",
        decorated_reason: :build_mismatch
      },
      {
        resource: "release",
        code: "review_in_progress",
        decorated_reason: :review_in_progress
      },
      {
        resource: "release",
        code: "review_already_created",
        decorated_reason: :review_submission_exists
      },
      {
        resource: "release",
        code: "phased_release_not_found",
        decorated_reason: :phased_release_not_found
      },
      {
        resource: "release",
        code: "release_already_prepared",
        decorated_reason: :release_already_exists
      }
    ]

    def self.reasons
      ERRORS.pluck(:decorated_reason).uniq.map(&:to_s)
    end

    def initialize(response_body = nil)
      @response_body = response_body
      super(handle)
    end

    def handle
      return :unknown_failure if response_body.blank? || match.nil?
      match[:decorated_reason]
    end

    private

    attr_reader :response_body

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
      response_body["error"]
    end
  end
end
