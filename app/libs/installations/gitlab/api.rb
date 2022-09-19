module Installations
  class Gitlab::Api
    include Vaultable
    attr_reader :oauth_access_token

    class TokenExpired < StandardError; end

    LIST_REPOS_URL = "https://gitlab.com/api/v4/projects"

    def initialize(oauth_access_token)
      @oauth_access_token = oauth_access_token
    end

    class << self
      include Vaultable

      OAUTH_ACCESS_TOKEN_URL = "https://gitlab.com/oauth/token"

      def oauth_access_token(code, redirect_uri)
        params = {
          form: {
            client_id: creds.integrations.gitlab.client_id,
            client_secret: creds.integrations.gitlab.client_secret,
            grant_type: :authorization_code,
            redirect_uri:,
            code:
          }
        }

        get_oauth_token(params)
      end

      def oauth_refresh_token(refresh_token, redirect_uri)
        params = {
          form: {
            client_id: creds.integrations.gitlab.client_id,
            client_secret: creds.integrations.gitlab.client_secret,
            grant_type: :refresh_token,
            redirect_uri:,
            refresh_token:
          }
        }

        get_oauth_token(params)
      end

      def get_oauth_token(params)
        HTTP
          .post(OAUTH_ACCESS_TOKEN_URL, params)
          .then { |response| response.body.to_s }
          .then { |body| JSON.parse(body) }
          .then { |json| json.slice("access_token", "refresh_token") }
          .then
          .detect(&:present?)
          .then { |tokens| OpenStruct.new tokens }
      end
    end

    def list_repos
      params = {
        params: {
          membership: true
        }
      }

      execute(LIST_REPOS_URL, params, :get)
        .then { |repositories| repositories.map { |repo| repo.slice("id", "path_with_namespace") } }
        .then { |responses| Installations::Response::Keys.normalize(responses) }
    end

    def execute(url, params, verb = :get)
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)
      status = response.status
      body = JSON.parse(response.body.to_s)
      raise TokenExpired if refresh_token?(status, body)
      body
    end

    def refresh_token?(status, body)
      status.eql?(401) && invalid_token?(body)
    end

    def invalid_token?(body)
      body["error"].eql?("invalid_token")
    end
  end
end
