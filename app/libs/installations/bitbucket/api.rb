module Installations
  class Bitbucket::Api
    include Vaultable
    attr_reader :oauth_access_token

    BASE_URL = "https://api.bitbucket.org/2.0"
    REPOS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}"
    REPO_HOOKS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/hooks"
    REPO_HOOK_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/hooks/{hook_id}"
    REPO_BRANCHES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/branches"
    REPO_BRANCH_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/branches/{branch_name}"
    REPO_TAGS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/tags"
    REPO_TAG_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/tags/{tag_name}"

    WEBHOOK_EVENTS = %w[repo:push pullrequest:created pullrequest:updated pullrequest:fulfilled pullrequest:rejected]

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

    def create_repo_webhook!(repo_slug, url, transforms)
      execute(:post, REPO_HOOKS_URL.expand(workspace: @workspace, repo_slug:).to_s, webhook_params(url))
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def update_repo_webhook!(repo_slug, hook_id, url, transforms)
      execute(:put, REPO_HOOK_URL.expand(workspace: @workspace, repo_slug:, hook_id:).to_s, webhook_params(url))
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_webhook(repo_slug, hook_id, transforms)
      execute(:get, REPO_HOOK_URL.expand(workspace: @workspace, repo_slug:, hook_id:).to_s)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def create_branch!(repo_slug, source_name, new_branch_name, source_type: :branch)
      ref =
        case source_type
        when :commit
          source_name
        when :branch
          get_branch(repo_slug, source_name).dig("target", "hash")
        when :tag

        else
          raise ArgumentError, "source can only be a branch, tag or commit"
        end

      params = {
        json: {
          name: new_branch_name,
          target: { hash: ref }
        }
      }

      execute(:post, REPO_BRANCHES_URL.expand(workspace: @workspace, repo_slug:).to_s, params)
    end

    def create_tag!(repo_slug, tag_name, sha)
      params = {
        json: {
          name: tag_name,
          target: { hash: sha }
        }
      }

      execute(:post, REPO_TAGS_URL.expand(workspace: @workspace, repo_slug:).to_s, params)
    end

    def branch_exists?(repo_slug, branch_name)
      get_branch(repo_slug, branch_name).present?
    # replace this with a granular error
    rescue Installations::Bitbucket::Error
      false
    end

    def tag_exists?(repo_slug, tag_name)
      get_tag(repo_slug, tag_name).present?
    # replace this with a granular error
    rescue Installations::Bitbucket::Error
      false
    end

    private

    def get_branch(repo_slug, branch_name)
      execute(:get, REPO_BRANCH_URL.expand(workspace: @workspace, repo_slug:, branch_name:).to_s)
    end

    def get_tag(repo_slug, tag_name)
      execute(:get, REPO_TAG_URL.expand(workspace: @workspace, repo_slug:, tag_name:).to_s)
    end

    def execute(verb, url, params = {})
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      return body unless error?(response.status)
      raise Installations::Bitbucket::Error.new(body)
    end

    def error?(code)
      code.between?(400, 499)
    end

    def webhook_params(url)
      {
        json: {
          description: "Tramline",
          url:,
          active: true,
          secret: nil,
          events: WEBHOOK_EVENTS
        }
      }
    end
  end
end
