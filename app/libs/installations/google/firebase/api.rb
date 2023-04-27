module Installations
  class Google::Firebase::Api
    FIREBASE_PUBLISHER = ::Google::Apis::FirebaseappdistributionV1
    SERVICE = FIREBASE_PUBLISHER::FirebaseAppDistributionService
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = FIREBASE_PUBLISHER::AUTH_CLOUD_PLATFORM
    CONTENT_TYPE = "application/octet-stream".freeze

    attr_reader :key_file, :client, :project_number, :app_id

    def initialize(project_number, app_id, key_file)
      @key_file = key_file
      @project_number = project_number
      @app_id = app_id

      set_api_defaults
      set_client
    end

    def upload(apk_path)
      execute do
        client.upload_medium(app_name, upload_source: apk_path, content_type: CONTENT_TYPE)&.name
      end
    end

    def send_to_group(release, group)
      execute do
        distro_request = FIREBASE_PUBLISHER::GoogleFirebaseAppdistroV1DistributeReleaseRequest.new(group_aliases: [group])
        client.distribute_project_app_release(release, distro_request)
      end
    end

    def get_upload_status(op_name)
      execute do
        client.get_project_app_release_operation(op_name)&.to_h
      end
    end

    def list_groups(transforms)
      execute do
        client.list_project_groups(project_name)
          &.groups
          &.map { |g| g.to_h }
          &.then { |groups| Installations::Response::Keys.transform(groups, transforms) }
      end
    end

    def list_releases
      execute do
        client.list_project_app_releases(app_name, page_size: 2)
          &.releases
          &.map { |r| r.to_h }
      end
    end

    private

    def project_name
      "projects/#{project_number}"
    end

    def app_name
      "#{project_name}/apps/#{app_id}"
    end

    def execute
      yield if block_given?
    rescue ::Google::Apis::ServerError, ::Google::Apis::ClientError, ::Google::Apis::AuthorizationError => e
      raise Installations::Google::Firebase::Error.new(e)
    end

    def set_client
      auth_client = SERVICE_ACCOUNT.make_creds(json_key_io: key_file, scope: SCOPE)
      service = SERVICE.new
      service.authorization = auth_client
      @client ||= service
    end

    def set_api_defaults
      ::Google::Apis::ClientOptions.default.read_timeout_sec = 150
      ::Google::Apis::ClientOptions.default.open_timeout_sec = 150
      ::Google::Apis::ClientOptions.default.send_timeout_sec = 150
      ::Google::Apis::RequestOptions.default.retries = 3
    end
  end
end
