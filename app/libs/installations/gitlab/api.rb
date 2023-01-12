module Installations
  class Gitlab::Api
    include Vaultable
    attr_reader :oauth_access_token

    class TokenExpired < StandardError; end

    LIST_PROJECTS_URL = "https://gitlab.com/api/v4/projects"
    PROJECT_HOOKS_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/hooks"
    CREATE_TAG_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/tags"
    BRANCH_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/branches/{branch_name}"
    CREATE_BRANCH_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/branches"
    MR_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests"
    MR_MERGE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{merge_request_iid}/merge"
    COMPARE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/compare"

    WEBHOOK_PERMISSIONS = {
      deployment_events: true,
      job_events: true,
      merge_requests_events: true,
      pipeline_events: true,
      push_events: true,
      releases_events: true,
      tag_push_events: true
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

    def list_projects(transforms)
      params = {
        params: {
          membership: true
        }
      }

      execute(:get, LIST_PROJECTS_URL, params)
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    def create_project_webhook!(project_id, url)
      params = {
        form: {
          id: project_id,
          url: url
        }.merge(WEBHOOK_PERMISSIONS)
      }

      execute(:post, PROJECT_HOOKS_URL.expand(project_id:).to_s, params)
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

    def create_pr!(project_id, target_branch, source_branch, title, description)
      # gitlab allows creating merge requests without any changes, but we avoid it
      raise Installations::Errors::PullRequestWithoutCommits unless diff?(project_id, source_branch, target_branch)

      params = {
        form: {
          source_branch:,
          target_branch:,
          title:,
          description:
        }
      }

      execute(:post, MR_URL.expand(project_id:).to_s, params)
    end

    def find_pr(project_id, target_branch, source_branch)
      params = {
        form: {
          source_branch:,
          target_branch:,
          state: "open"
        }
      }

      execute(:get, MR_URL.expand(project_id:).to_s, params).first
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
