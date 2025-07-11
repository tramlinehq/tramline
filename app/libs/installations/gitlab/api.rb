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
    GET_TAG_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/tags/{tag_name}"
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
          membership: true,
          per_page: 50
        }
      }

      paginated_execute(:get, LIST_PROJECTS_URL, params: params, max_results: 200)
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

    def create_branch!(project_id, source_name, new_branch_name, source_type: :branch)
      ref =
        case source_type
        when :branch, :commit
          source_name
        when :tag
          "refs/tags/#{source_name}"
        else
          raise ArgumentError, "source can only be a branch, tag or commit"
        end

      params = {
        form: {
          branch: new_branch_name,
          ref: ref
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
      raise Installations::Error.new("Should not create a Pull Request without a diff", reason: :pull_request_without_commits) unless diff?(project_id, target_branch, source_branch)

      params = {
        form: {
          source_branch:,
          target_branch:,
          title:,
          description:
        }
      }

      execute(:post, MR_URL.expand(project_id:).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
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

    def merge_pr!(project_id, pr_number, transforms)
      execute(:put, MR_MERGE_URL.expand(project_id:, merge_request_iid: pr_number).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
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
      execute(:get, GET_TAG_URL.expand(project_id:, tag_name:).to_s, {}).present?
    end

    def head(project_id, branch_name, sha_only: true, commit_transforms: nil)
      raise ArgumentError, "transforms must be supplied when querying head object" if !sha_only && !commit_transforms

      sha = get_branch(project_id, branch_name).dig("commit", "id")
      return sha if sha_only
      get_commit(project_id, sha, commit_transforms)
    end

    def get_branch(project_id, branch_name)
      execute(:get, GET_BRANCH_URL.expand(project_id:, branch_name:).to_s, {})
    end

    private

    def execute(verb, url, params)
      response = raw_execute(verb, url, params)
      JSON.parse(response.body.to_s)
    end

    def raw_execute(verb, url, params)
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)

      return response unless error?(response.status)
      raise Installations::Gitlab::Error.new(JSON.parse(response.body))
    end

    def paginated_execute(verb, url, params: {}, values: [], page: nil, max_results: nil)
      url = URI(url)
      url.query = "page=#{page}" if page.present?

      response = raw_execute(verb, url, params)
      values.concat(JSON.parse(response.body))

      next_page = response.headers["x-next-page"]
      return values if next_page.blank?
      return values if max_results && values.length >= max_results

      paginated_execute(verb, url, params: params, values: values, page: next_page, max_results: max_results)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end
