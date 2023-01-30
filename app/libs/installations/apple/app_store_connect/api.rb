module Installations
  class Apple::AppStoreConnect::Api
    include Vaultable

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

    def external_groups(transforms)
      execute(:get, GROUPS_URL.expand(bundle_id:).to_s, {params: {internal: false}})
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    def find_app
      execute(:get, FIND_APP_URL.expand(bundle_id:).to_s, {})
    end

    def find_build(build_number, transforms)
      execute(:get, FIND_BUILD_URL.expand(bundle_id:, build_number:).to_s, {})
        .then { |build| build&.presence || raise(Installations::Errors::BuildNotFoundInStore) }
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def add_build_to_group(group_id, build_number)
      execute(:patch, ADD_BUILD_TO_GROUP_URL.expand(bundle_id:, group_id: group_id).to_s, {json: {build_number: build_number}})
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

      return if error?(response.status)
      return if no_content?(response.status)

      JSON.parse(response.body.to_s)
    end

    def error?(code)
      code.between?(400, 499)
    end

    def no_content?(code)
      code == 204
    end
  end
end
