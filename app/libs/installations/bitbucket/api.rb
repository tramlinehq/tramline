module Installations
  class Bitbucket::Api
    include Vaultable
    attr_reader :oauth_access_token

    REPOS_URL = Addressable::Template.new "https://api.bitbucket.org/2.0/repositories/{workspace}"

    class << self
      include Vaultable

      OAUTH_ACCESS_TOKEN_URL = "https://bitbucket.org/site/oauth2/access_token"

      def oauth_access_token(code, redirect_uri)
        params = {
          form: {
            grant_type: :authorization_code,
            code:,
            redirect_uri:
          }
        }

        get_oauth_token(params)
      end

      def oauth_refresh_token(refresh_token, redirect_uri)
        params = {
          form: {
            grant_type: :refresh_token,
            redirect_uri:,
            refresh_token:
          }
        }

        get_oauth_token(params)
      end

      def get_oauth_token(params)
        HTTP
          .basic_auth(user: creds.integrations.bitbucket.client_id, pass: creds.integrations.bitbucket.client_secret)
          .post(OAUTH_ACCESS_TOKEN_URL, params)
          .then { |response| response.body.to_s }
          .then { |body| JSON.parse(body) }
          .then { |json| json.slice("access_token", "refresh_token") }
          .then.detect(&:present?)
          .then { |tokens| OpenStruct.new tokens }
      end
    end

    def initialize(oauth_access_token, workspace)
      @oauth_access_token = oauth_access_token
      @workspace = workspace
    end

    def list_repos(transforms)
      execute(:get, REPOS_URL.expand(workspace: @workspace).to_s)
        .then { |responses| Installations::Response::Keys.transform(responses["values"], transforms) }
    end

    private

    def execute(verb, url, params = {})
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      return body unless error?(response.status)
      raise Installations::Bitbucket::Error.new(body)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end
