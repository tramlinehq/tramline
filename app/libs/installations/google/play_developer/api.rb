module Installations
  class Google::PlayDeveloper::Api
    include Vaultable

    ANDROID_PUBLISHER = ::Google::Apis::AndroidpublisherV3
    SERVICE = ANDROID_PUBLISHER::AndroidPublisherService
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = ANDROID_PUBLISHER::AUTH_ANDROIDPUBLISHER

    CONTENT_TYPE = "application/octet-stream".freeze

    attr_reader :package_name, :apk_path, :key_file, :track_name, :client

    def initialize(package_name, apk_path, key_file, track_name)
      @package_name = package_name
      @apk_path = apk_path
      @key_file = File.open(File.expand_path(key_file))
      @track_name = track_name
      @errors = []

      set_api_defaults
      set_client
    end

    def upload
      execute do
        edit = client.insert_edit(package_name)
        apk = client.upload_edit_bundle(package_name, edit.id, upload_source: apk_path, content_type: CONTENT_TYPE)
        client.update_edit_track(package_name, edit.id, track_name, track(apk.version_code))
        client.commit_edit(package_name, edit.id)
      end
    end

    def track(version_code)
      ANDROID_PUBLISHER::Track.new(track: track_name, version_codes: [version_code], releases: [release])
    end

    def release
      ANDROID_PUBLISHER::TrackRelease.new(name: "ueno", status: "draft")
    end

    def execute
      yield if block_given?
    rescue ::Google::Apis::Error => e
      error =
        begin
          JSON.parse(e.body)
        rescue StandardError
          nil
        end

      @errors =
        if error
          error["error"] && error["error"]["message"]
        else
          e.body
        end
    end

    def set_client
      auth_client = SERVICE_ACCOUNT.make_creds(json_key_io: key_file, scope: SCOPE)
      service = SERVICE.new
      service.authorization = auth_client
      @client ||= service
    end

    def set_api_defaults
      ::Google::Apis::ClientOptions.default.read_timeout_sec = 50
      ::Google::Apis::ClientOptions.default.open_timeout_sec = 50
      ::Google::Apis::ClientOptions.default.send_timeout_sec = 50
      ::Google::Apis::RequestOptions.default.retries = 3
    end
  end
end
