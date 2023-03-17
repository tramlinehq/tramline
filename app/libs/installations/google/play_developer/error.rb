module Installations
  class Google::PlayDeveloper::Error < Installations::Error
    using RefinedString

    ERRORS = [
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /APK specifies a version code that has already been used/,
        decorated_reason: :build_exists_in_build_channel
      },
      {
        status: "NOT_FOUND",
        code: 404,
        message_matcher: /Package not found:/,
        decorated_reason: :app_not_found
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /You cannot rollout this release because it does not allow any existing users to upgrade to the newly added APKs/,
        decorated_reason: :build_not_upgradable
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /The caller does not have permission/,
        decorated_reason: :permission_denied
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /Google Play Android Developer API has not been used in project/,
        decorated_reason: :api_disabled
      },
      {
        status: "FAILED_PRECONDITION",
        code: 400,
        message_matcher: /This Edit has been deleted/,
        decorated_reason: :duplicate_build_upload
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /APK is not a valid ZIP archive/,
        decorated_reason: :invalid_api_package
      },
      {
        status: "PERMISSION_DENIED",
        code: 403,
        message_matcher: /We have failed to run 'bundletool build-apks' on this Android App Bundle. Please ensure your bundle is valid by running 'bundletool build-apks' locally and try again. Error message output: File 'BundleConfig.pb' was not found/,
        decorated_reason: :apks_not_allowed
      }
    ]

    def self.reasons
      ERRORS.pluck(:decorated_reason).uniq.map(&:to_s)
    end

    def initialize(api_error)
      @api_error = api_error
      log
      super(handle)
    end

    def handle
      return :unknown_failure if match.nil?
      match[:decorated_reason]
    end

    private

    attr_reader :api_error
    delegate :logger, to: Rails

    def match
      @match ||= matched_error
    end

    def matched_error
      ERRORS.find do |known_error|
        known_error[:status].eql?(status) &&
          known_error[:code].eql?(code) &&
          known_error[:message_matcher] =~ error_message
      end
    end

    def parsed_body
      @parsed_body ||= api_error&.body&.safe_json_parse
    end

    def error_body
      return api_error.body if parsed_body.blank?
      parsed_body["error"]
    end

    def error_message
      error_body["message"]
    end

    def code
      error_body["code"]
    end

    def status
      error_body["status"]
    end

    def log
      logger.error(api_error)
    end
  end
end
