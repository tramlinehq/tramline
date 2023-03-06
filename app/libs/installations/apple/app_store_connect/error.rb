module Installations
  class Apple::AppStoreConnect::Error
    ERRORS = [
      {
        resource: "app",
        code: "not_found",
        decorated_exception: Installations::Errors::AppNotFoundInStore
      },
      {
        resource: "build",
        code: "not_found",
        decorated_exception: Installations::Errors::BuildNotFoundInStore
      },
      {
        resource: "build",
        code: "export_compliance_not_updateable",
        decorated_exception: Installations::Errors::AppStoreBuildNotSubmittable
      },
      {
        resource: "beta_group",
        code: "not_found",
        decorated_exception: Installations::Errors::BetaGroupNotFound
      },
      {
        resource: "release",
        code: "not_found",
        decorated_exception: Installations::Errors::ReleaseNotFoundInStore
      },
      {
        resource: "release",
        code: "review_submission_not_allowed",
        decorated_exception: Installations::Errors::AppStoreReviewSubmissionNotAllowed
      },
      {
        resource: "release",
        code: "build_mismatch",
        decorated_exception: Installations::Errors::AppStoreBuildMismatch
      },
      {
        resource: "release",
        code: "review_in_progress",
        decorated_exception: Installations::Errors::AppStoreReviewInProgress
      },
      {
        resource: "release",
        code: "review_already_created",
        decorated_exception: Installations::Errors::AppStoreReviewSubmissionExists
      },
      {
        resource: "release",
        code: "phased_release_not_found",
        decorated_exception: Installations::Errors::PhasedReleaseNotFound
      },
      {
        resource: "release",
        code: "release_already_prepared",
        decorated_exception: Installations::Errors::ReleaseAlreadyExists
      }
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
