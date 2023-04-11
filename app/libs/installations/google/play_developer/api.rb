module Installations
  class Google::PlayDeveloper::Api
    include Vaultable

    ANDROID_PUBLISHER = ::Google::Apis::AndroidpublisherV3
    SERVICE = ANDROID_PUBLISHER::AndroidPublisherService
    SERVICE_ACCOUNT = ::Google::Auth::ServiceAccountCredentials
    SCOPE = ANDROID_PUBLISHER::AUTH_ANDROIDPUBLISHER
    CONTENT_TYPE = "application/octet-stream".freeze

    RELEASE_STATUS = {
      in_progress: "inProgress",
      halted: "halted",
      draft: "draft",
      completed: "completed"
    }.freeze

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

    def list_tracks(transforms)
      execute do
        edit = client.insert_edit(package_name)
        client.list_edit_tracks(package_name, edit.id)
          &.tracks
          &.map { |t| t.to_h }
          &.then { |tracks| Installations::Response::Keys.transform(tracks, transforms) }
      end
    end

    def create_release(track_name, version_code, release_version, rollout_percentage, release_notes)
      @track_name = track_name
      @version_code = version_code
      @release_version = release_version
      @rollout_percentage = rollout_percentage
      @release_notes = release_notes

      execute do
        edit = client.insert_edit(package_name)
        edit_track(edit, active_release)
        client.commit_edit(package_name, edit.id)
      end
    end

    def create_draft_release(track_name, version_code, release_version, release_notes)
      @track_name = track_name
      @version_code = version_code
      @release_version = release_version
      @release_notes = release_notes

      execute do
        edit = client.insert_edit(package_name)
        edit_track(edit, draft_release)
        client.commit_edit(package_name, edit.id)
      end
    end

    def halt_release(track_name, version_code, release_version, rollout_percentage)
      @track_name = track_name
      @version_code = version_code
      @release_version = release_version
      @rollout_percentage = rollout_percentage

      execute do
        edit = client.insert_edit(package_name)
        edit_track(edit, halted_release)
        client.commit_edit(package_name, edit.id)
      end
    end

    private

    attr_writer :track_name, :version_code, :release_version, :rollout_percentage

    def edit_track(edit, release)
      client.update_edit_track(package_name, edit.id, @track_name, track(release))
    end

    def track(release)
      ANDROID_PUBLISHER::Track.new(track: @track_name, releases: [release])
    end

    def active_release
      rollout_status = @rollout_percentage.eql?(100) ? RELEASE_STATUS[:completed] : RELEASE_STATUS[:in_progress]
      params = release_params.merge(status: rollout_status, release_notes: @release_notes)
      params[:user_fraction] = user_fraction if @rollout_percentage && user_fraction < 1.0
      ANDROID_PUBLISHER::TrackRelease.new(**params)
    end

    def draft_release
      params = release_params.merge(status: RELEASE_STATUS[:draft], release_notes: @release_notes)
      ANDROID_PUBLISHER::TrackRelease.new(**params)
    end

    def halted_release
      params = release_params.merge(status: RELEASE_STATUS[:halted], user_fraction: user_fraction)
      ANDROID_PUBLISHER::TrackRelease.new(**params)
    end

    def user_fraction
      @rollout_percentage.to_f / 100.0
    end

    def release_params
      {name: @release_version, version_codes: [@version_code]}
    end

    def execute
      yield if block_given?
    rescue ::Google::Apis::ServerError, ::Google::Apis::ClientError => e
      raise Installations::Google::PlayDeveloper::Error.new(e)
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
