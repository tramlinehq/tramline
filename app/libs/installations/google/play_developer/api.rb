module Installations
  class Google::PlayDeveloper::Api
    include Vaultable

    ANDROID_PUBLISHER = ::Google::Apis::AndroidpublisherV3
    SERVICE = ANDROID_PUBLISHER::AndroidPublisherService
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = ANDROID_PUBLISHER::AUTH_ANDROIDPUBLISHER
    CONTENT_TYPE = "application/octet-stream".freeze

    attr_reader :package_name, :key_file, :client

    def initialize(package_name, key_file)
      @package_name = package_name
      @key_file = key_file

      set_api_defaults
      set_client
    end

    def upload(apk_path)
      execute do
        edit = client.insert_edit(package_name)
        client.upload_edit_bundle(package_name, edit.id, upload_source: apk_path, content_type: CONTENT_TYPE)
        client.commit_edit(package_name, edit.id)
      end
    end

    def promote(track_name, version_code, release_version, rollout_percentage)
      rollout_percentage = BigDecimal(rollout_percentage)

      execute do
        edit = client.insert_edit(package_name)
        edit_track(edit, track_name, version_code, release_version, rollout_percentage)
        client.commit_edit(package_name, edit.id)
      end
    end

    # NOTE: is list_bundles too expensive an operation?
    def list_bundles
      execute do
        edit = client.insert_edit(package_name)
        client
          .list_edit_bundles(package_name, edit.id)
          &.bundles
          .to_h { |b| [b.sha256, {version_code: b.version_code}] } || {}
      end
    end

    def list_tracks(transforms, nested_transforms)
      execute do
        edit = client.insert_edit(package_name)
        client.list_edit_tracks(package_name, edit.id)
          &.tracks
          &.map { |t| t.to_h }
          &.then do |tracks|
          Installations::Response::Keys.transform(tracks, transforms).map do |track|
            track[:releases] = Installations::Response::Keys.transform(track[:releases], nested_transforms)
            track
          end
        end
      end
    end

    def edit_track(edit, track_name, version_code, release_version, rollout_percentage)
      client.update_edit_track(
        package_name,
        edit.id,
        track_name,
        track(track_name, version_code, release_version, rollout_percentage)
      )
    end

    def track(track_name, version_code, release_version, rollout_percentage)
      ANDROID_PUBLISHER::Track.new(
        track: track_name,
        releases: [release(version_code, release_version, rollout_percentage)]
      )
    end

    def release(version_code, release_version, rollout_percentage)
      params = {
        name: release_version,
        status: release_status(rollout_percentage),
        version_codes: [version_code]
      }

      user_fraction = user_fraction(rollout_percentage)
      params[:user_fraction] = user_fraction if user_fraction < 1.0

      ANDROID_PUBLISHER::TrackRelease.new(**params)
    end

    def user_fraction(rollout_percentage)
      rollout_percentage.to_f / 100.0
    end

    def release_status(rollout_percentage)
      rollout_percentage.eql?(100) ? "completed" : "inProgress"
    end

    def execute
      yield if block_given?
    rescue ::Google::Apis::ServerError, ::Google::Apis::ClientError => e
      raise Installations::Google::PlayDeveloper::Error.handle(e)
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
