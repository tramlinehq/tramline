module Installations
  class Google::PlayDeveloper::Api
    include Vaultable

    ANDROID_PUBLISHER = ::Google::Apis::AndroidpublisherV3
    SERVICE = ANDROID_PUBLISHER::AndroidPublisherService
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = ANDROID_PUBLISHER::AUTH_ANDROIDPUBLISHER

    CONTENT_TYPE = "application/octet-stream".freeze

    attr_reader :package_name, :apk_path, :key_file, :track_name, :release_version, :client, :errors

    def initialize(package_name, apk_path, key_file, track_name, release_version, should_promote: true)
      @package_name = package_name
      @apk_path = apk_path
      @key_file = key_file
      @track_name = track_name
      @release_version = release_version
      @should_promote = should_promote
      @errors = []

      set_api_defaults
      set_client
    end

    def upload
      execute do
        edit = client.insert_edit(package_name)
        apk = client.upload_edit_bundle(package_name, edit.id, upload_source: apk_path, content_type: CONTENT_TYPE)
        edit_track(edit, apk.version_code) if @should_promote
        client.commit_edit(package_name, edit.id)
      end
    end

    def promote(version_code)
      execute do
        edit = client.insert_edit(package_name)
        edit_track(edit, version_code)
        client.commit_edit(package_name, edit.id)
      end
    end

    def edit_track(edit, version_code)
      client.update_edit_track(package_name, edit.id, track_name, track(version_code))
    end

    def track(version_code)
      ANDROID_PUBLISHER::Track.new(track: track_name, releases: [release(version_code)])
    end

    def release(version_code)
      ANDROID_PUBLISHER::TrackRelease.new(name: release_version, status: "completed", version_codes: [version_code])
    end

    def execute
      yield if block_given?
    rescue ::Google::Apis::ServerError, ::Google::Apis::ClientError => e
      error =
        begin
          JSON.parse(e.body)
        rescue
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
      ::Google::Apis::ClientOptions.default.read_timeout_sec = 100
      ::Google::Apis::ClientOptions.default.open_timeout_sec = 100
      ::Google::Apis::ClientOptions.default.send_timeout_sec = 100
      ::Google::Apis::RequestOptions.default.retries = 3
    end
  end
end
