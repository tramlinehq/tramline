module Installations
  class Google::PlayDeveloper::Error
    using RefinedString

    ERRORS = [
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /APK specifies a version code that has already been used/,
        decorated_exception: Installations::Errors::BuildExistsInBuildChannel
      },
      {
        status: "NOT_FOUND",
        code: 404,
        message_matcher: /Package not found:/,
        decorated_exception: Installations::Errors::BundleIdentifierNotFound
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /You cannot rollout this release because it does not allow any existing users to upgrade to the newly added APKs/,
        decorated_exception: Installations::Errors::BuildNotUpgradable
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /The caller does not have permission/,
        decorated_exception: Installations::Errors::GooglePlayDeveloperAPIPermissionDenied
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /Google Play Android Developer API has not been used in project/,
        decorated_exception: Installations::Errors::GooglePlayDeveloperAPIDisabled
      },
      {
        status: "FAILED_PRECONDITION",
        code: 400,
        message_matcher: /This Edit has been deleted/,
        decorated_exception: Installations::Errors::DuplicatedBuildUploadAttempt
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /APK is not a valid ZIP archive/,
        decorated_exception: Installations::Errors::GooglePlayDeveloperAPIInvalidPackage
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /We have failed to run 'bundletool build-apks' on this Android App Bundle. Please ensure your bundle is valid by running 'bundletool build-apks' locally and try again. Error message output: File 'BundleConfig.pb' was not found/,
        decorated_exception: Installations::Errors::GooglePlayDeveloperAPIAPKsAreNotAllowed
      }
    ]

    def self.handle(exception)
      new(exception).handle
    end

    def initialize(exception)
      @exception = exception
    end

    def handle
      log
      return exception if match.nil?
      match[:decorated_exception].new
    end

    private

    attr_reader :exception
    delegate :logger, to: Rails

    def match
      @match ||= matched_error
    end

    def matched_error
      ERRORS.find do |known_error|
        known_error[:status].eql?(status) && known_error[:code].eql?(code) && known_error[:message_matcher] =~ message
      end
    end

    def parsed_body
      @parsed_body ||= exception.body.safe_json_parse
    end

    def error
      return exception.body if parsed_body.blank?
      parsed_body["error"]
    end

    def message
      error["message"]
    end

    def code
      error["code"]
    end

    def status
      error["status"]
    end

    def log
      logger.error(error)
    end
  end
end
