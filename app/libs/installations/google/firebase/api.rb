module Installations
  class Google::Firebase::Api
    FAD_PUBLISHER = ::Google::Apis::FirebaseappdistributionV1
    FIREBASE_PUBLISHER = ::Google::Apis::FirebaseV1beta1
    FAD_SERVICE = FAD_PUBLISHER::FirebaseAppDistributionService
    FIREBASE_SERVICE = FIREBASE_PUBLISHER::FirebaseManagementService
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = FIREBASE_PUBLISHER::AUTH_CLOUD_PLATFORM
    CONTENT_TYPE = "application/octet-stream".freeze

    attr_reader :key_file, :project_number
    attr_reader :fad_client, :firebase_client

    def initialize(project_number, key_file)
      @key_file = key_file
      @project_number = project_number

      set_api_defaults
      set_clients
    end

    def upload(apk_path, filename, app_id)
      options = ::Google::Apis::RequestOptions.new
      options.header = {"X-Goog-Upload-File-Name" => filename}
      execute do
        fad_client.upload_medium(app_name(app_id), upload_source: apk_path, content_type: CONTENT_TYPE, options:)&.name
      end
    end

    def send_to_group(release, group)
      execute do
        distro_request = FAD_PUBLISHER::GoogleFirebaseAppdistroV1DistributeReleaseRequest.new(group_aliases: [group])
        fad_client.distribute_project_app_release(release, distro_request)
      end
    end

    def update_release_notes(release, notes)
      execute do
        release = FAD_PUBLISHER::GoogleFirebaseAppdistroV1Release.from_json(release.to_json)
        release.release_notes = FAD_PUBLISHER::GoogleFirebaseAppdistroV1ReleaseNotes.new(text: notes)
        fad_client.patch_project_app_release(release.name, release)
      end
    end

    def get_upload_status(op_name)
      execute do
        fad_client.get_project_app_release_operation(op_name)&.to_h
      end
    end

    def list_groups(transforms)
      execute do
        fad_client.list_project_groups(project_name)
          &.groups
          &.map { |g| g.to_h }
          &.then { |groups| Installations::Response::Keys.transform(groups, transforms) }
      end
    end

    # fetch apps for both android and ios
    # but add a platform key so that they can be filtered upstream
    def list_apps(transforms)
      execute do
        android_apps = []
        ios_apps = []

        t1 = Thread.new do
          android_apps
            .concat(firebase_client
                      .list_project_android_apps(project_name, page_size: 20)
                      &.apps
                      &.map { |app| app.to_h.merge(platform: "android") })
        end

        t2 = Thread.new do
          ios_apps
            .concat(firebase_client
                      .list_project_ios_apps(project_name, page_size: 20)
                      &.apps
                      &.map { |app| app.to_h.merge(platform: "ios") })
        end

        [t1, t2].each(&:join)
        apps = android_apps + ios_apps
        Installations::Response::Keys.transform(apps, transforms)
      end
    end

    def project_name
      "projects/#{project_number}"
    end

    def app_name(app_id)
      "#{project_name}/apps/#{app_id}"
    end

    def execute
      yield if block_given?
    rescue ::Google::Apis::ServerError, ::Google::Apis::ClientError, ::Google::Apis::AuthorizationError => e
      raise Installations::Google::Firebase::Error.new(e)
    end

    def set_clients
      set_fad_client
      set_firebase_client
    end

    def set_fad_client
      service = FAD_SERVICE.new
      service.authorization = auth_client
      @fad_client ||= service
    end

    def set_firebase_client
      service = FIREBASE_SERVICE.new
      service.authorization = auth_client
      @firebase_client ||= service
    end

    def auth_client
      key_file.rewind # so that multiple calls to this method always start the key file from 0 offset
      SERVICE_ACCOUNT.make_creds(json_key_io: key_file, scope: SCOPE)
    end

    def set_api_defaults
      ::Google::Apis::ClientOptions.default.read_timeout_sec = 150
      ::Google::Apis::ClientOptions.default.open_timeout_sec = 150
      ::Google::Apis::ClientOptions.default.send_timeout_sec = 150
      ::Google::Apis::RequestOptions.default.retries = 3
    end
  end
end
