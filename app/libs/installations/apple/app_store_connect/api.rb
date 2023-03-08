module Installations
  class Apple::AppStoreConnect::Api
    include Vaultable

    UnknownError = Class.new(StandardError)

    def initialize(bundle_id, key_id, issuer_id, key)
      @bundle_id = bundle_id
      @key_id = key_id
      @issuer_id = issuer_id
      @key = key
    end

    GROUPS_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/groups"
    FIND_APP_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}"
    FIND_BUILD_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/builds/{build_number}"
    ADD_BUILD_TO_GROUP_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/groups/{group_id}/add_build"
    APP_CURRENT_STATUS = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/current_status"
    PREPARE_RELEASE_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/prepare"
    SUBMIT_RELEASE_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/submit"
    START_RELEASE_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/start"
    FIND_RELEASE_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release"
    FIND_LIVE_RELEASE_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/live"
    PAUSE_LIVE_ROLLOUT_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/live/pause_rollout"
    RESUME_LIVE_ROLLOUT_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/live/resume_rollout"
    HALT_LIVE_ROLLOUT_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/live/halt_rollout"
    COMPLETE_LIVE_ROLLOUT_URL = Addressable::Template.new "#{ENV["APPLELINK_URL"]}/apple/connect/v1/apps/{bundle_id}/release/live/complete_rollout"

    def external_groups(transforms)
      execute(:get, GROUPS_URL.expand(bundle_id:).to_s, {params: {internal: false}})
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    def find_app(transforms)
      execute(:get, FIND_APP_URL.expand(bundle_id:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_build(build_number, transforms)
      execute(:get, FIND_BUILD_URL.expand(bundle_id:, build_number:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_release(build_number, transforms)
      execute(:get, FIND_RELEASE_URL.expand(bundle_id:).to_s, {params: {build_number:}})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_live_release(transforms)
      execute(:get, FIND_LIVE_RELEASE_URL.expand(bundle_id:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def add_build_to_group(group_id, build_number)
      execute(:patch, ADD_BUILD_TO_GROUP_URL.expand(bundle_id:, group_id: group_id).to_s,
        {json: {build_number:}})
    end

    def current_app_status(transforms)
      execute(:get, APP_CURRENT_STATUS.expand(bundle_id:).to_s, {})
        .then { |tracks| Installations::Response::Keys.transform(tracks, transforms) }
    end

    def prepare_release(build_number, version, is_phased_release, transforms = {})
      params = {
        build_number:,
        version:,
        is_phased_release:,
        metadata: { whats_new: "The latest version contains bug fixes and performance improvements." }
      }

      execute(:post, PREPARE_RELEASE_URL.expand(bundle_id:).to_s, {json: params})
    end

    def submit_release(build_number, transforms = {})
      execute(:patch, SUBMIT_RELEASE_URL.expand(bundle_id:).to_s, {json: {build_number:}})
    end

    def start_release(build_number, transforms = {})
      execute(:patch, START_RELEASE_URL.expand(bundle_id:).to_s, {json: {build_number:}})
    end

    def pause_phased_release
      execute(:patch, PAUSE_LIVE_ROLLOUT_URL.expand(bundle_id:).to_s, {})
    end

    def resume_phased_release
      execute(:patch, RESUME_LIVE_ROLLOUT_URL.expand(bundle_id:).to_s, {})
    end

    def halt_phased_release
      execute(:patch, HALT_LIVE_ROLLOUT_URL.expand(bundle_id:).to_s, {})
    end

    def complete_phased_release
      execute(:patch, COMPLETE_LIVE_ROLLOUT_URL.expand(bundle_id:).to_s, {})
    end

    private

    attr_reader :key_id, :key, :issuer_id, :bundle_id

    def appstore_connect_headers
      {
        "X-AppStoreConnect-Key-Id" => key_id,
        "X-AppStoreConnect-Issuer-Id" => issuer_id,
        "X-AppStoreConnect-Token" => appstore_connect_token
      }
    end

    def appstore_connect_token
      header = {
        kid: key_id,
        typ: "JWT"
      }

      Apple::AppStoreConnect::Jwt.encode(
        key:,
        algo: "ES256",
        iss: issuer_id,
        aud: "appstoreconnect-v1",
        header: header
      )
    end

    def access_token
      "Bearer #{auth_token}"
    end

    def auth_token
      Apple::AppStoreConnect::Jwt.encode(
        key: applelink_creds.secret,
        algo: "HS256",
        iss: applelink_creds.iss,
        aud: applelink_creds.aud
      )
    end

    def applelink_creds
      creds.integrations.applelink
    end

    def execute(verb, url, params)
      response = HTTP.auth(access_token.to_s).headers(appstore_connect_headers).public_send(verb, url, params)
      raise UnknownError if _5xx?(response.status)

      return true if no_content?(response.status)
      body = JSON.parse(response.body.to_s)
      raise Installations::Apple::AppStoreConnect::Error.new(body) if error?(response.status)
      body
    end

    def _5xx?(code)
      code.between?(500, 599)
    end

    def error?(code)
      code.between?(400, 499)
    end

    def no_content?(code)
      code == 204
    end
  end
end
