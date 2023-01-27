module Installations
  class Apple::AppStoreConnect::Api
    include Vaultable

    def initialize(bundle_id, key_id, issuer_id, key)
      @bundle_id = bundle_id
      @key_id = key_id
      @issuer_id = issuer_id
      @key = key
    end

    FIND_APP_URL = Addressable::Template.new "http://localhost:9292/apple/connect/v1/apps/{bundle_id}"

    def find_app
      execute(:get, FIND_APP_URL.expand(bundle_id:).to_s, {})
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
      JSON.parse(response.body.to_s)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end
