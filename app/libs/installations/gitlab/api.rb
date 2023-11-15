module Installations
  class Gitlab::Api
    include Vaultable
    attr_reader :oauth_access_token

    class TokenExpired < StandardError; end

    USER_INFO_URL = "https://gitlab.com/api/v4/user"
    LIST_PROJECTS_URL = "https://gitlab.com/api/v4/projects"
    PROJECT_HOOKS_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/hooks"
    PROJECT_HOOK_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/hooks/{hook_id}"
    CREATE_TAG_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/tags"
    BRANCH_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/branches/{branch_name}"
    CREATE_BRANCH_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/branches"
    MR_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests"
    GET_MR_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{merge_request_iid}"
    MR_MERGE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{merge_request_iid}/merge"
    COMPARE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/compare"
    GET_COMMIT_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/commits/{sha}"
    GET_BRANCH_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/branches/{branch_name}"

    WEBHOOK_PERMISSIONS = {
      push_events: true,
      merge_requests_events: true
    }

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

    def user_info(transforms)
      execute(:get, USER_INFO_URL, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def get_commit(project_id, sha, transforms)
      execute(:get, GET_COMMIT_URL.expand(project_id:, sha:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def list_projects(transforms)
      params = {
        params: {
          membership: true
        }
      }

      execute(:get, LIST_PROJECTS_URL, params)
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    def create_project_webhook!(project_id, url, transforms)
      params = {
        form: {
          id: project_id,
          url: url
        }.merge(WEBHOOK_PERMISSIONS)
      }

      execute(:post, PROJECT_HOOKS_URL.expand(project_id:).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_webhook(project_id, hook_id, transforms)
      execute(:get, PROJECT_HOOK_URL.expand(project_id:, hook_id:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def create_branch!(project_id, from_branch_name, new_branch_name)
      params = {
        form: {
          branch: new_branch_name,
          ref: from_branch_name
        }
      }

      execute(:post, CREATE_BRANCH_URL.expand(project_id:).to_s, params)
    end

    def create_tag!(project_id, tag_name, branch_name)
      params = {
        form: {
          tag_name:,
          ref: branch_name
        }
      }

      execute(:post, CREATE_TAG_URL.expand(project_id:).to_s, params)
    end

    def create_pr!(project_id, target_branch, source_branch, title, description, transforms)
      # gitlab allows creating merge requests without any changes, but we avoid it
      raise Installations::Errors::PullRequestWithoutCommits unless diff?(project_id, target_branch, source_branch)

      params = {
        form: {
          source_branch:,
          target_branch:,
          title:,
          description:
        }
      }

      execute(:post, MR_URL.expand(project_id:).to_s, params)
        .then { |response| Installations::Response::Keys.transform(response, transforms) }
    end

    def find_pr(project_id, target_branch, source_branch, transforms)
      params = {
        form: {
          source_branch:,
          target_branch:,
          state: "opened"
        }
      }

      execute(:get, MR_URL.expand(project_id:).to_s, params)
        .then { |response| Installations::Response::Keys.transform(response, transforms) }
        .first
    end

    def get_pr(project_id, pr_number, transforms)
      execute(:get, GET_MR_URL.expand(project_id:, merge_request_iid: pr_number).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def merge_pr!(project_id, pr_number)
      execute(:put, MR_MERGE_URL.expand(project_id:, merge_request_iid: pr_number).to_s, {})
    end

    def diff?(project_id, from, to)
      params = {
        params: {
          from:,
          to:,
          straight: false # `git diff from...to`
        }
      }

      execute(:get, COMPARE_URL.expand(project_id:).to_s, params)["diffs"].present?
    end

    def commits_between(project_id, from, to, transforms)
      params = {
        params: {
          from:,
          to:,
          straight: false # `git diff from...to`
        }
      }

      execute(:get, COMPARE_URL.expand(project_id:).to_s, params)
        .dig("commits")
        .then { |commits| Installations::Response::Keys.transform(commits, transforms) }
    end

    def branch_exists?(project_id, branch_name)
      get_branch(project_id, branch_name).present?
    end

    def tag_exists?(project_id, tag_name)
      true
    end

    def head(project_id, branch_name, sha_only: true)
      return get_branch(project_id, branch_name).dig("commit", "id") if sha_only
      get_branch(project_id, branch_name).dig("commit")
    end

    def get_branch(project_id, branch_name)
      execute(:get, GET_BRANCH_URL.expand(project_id:, branch_name:).to_s, {})
    end

    private

    def execute(verb, url, params)
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      return body unless error?(response.status)
      raise Installations::Gitlab::Error.handle(body)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end
