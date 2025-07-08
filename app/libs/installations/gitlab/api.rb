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
    GET_FILE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/files/{file_path}{?ref}"
    CREATE_RELEASE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/releases"
    RUN_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipeline{?ref}"
    CANCEL_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}/cancel"
    RETRY_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}/retry"
    GET_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}"
    CHERRY_PICK_PR_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{merge_request_iid}/cherry_pick"
    CHERRY_PICK_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/commits/{sha}/cherry_pick"

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

    # https://docs.gitlab.com/ee/api/users.html#get-the-currently-authenticated-user
    def user_info(transforms)
      execute(:get, USER_INFO_URL, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/commits.html#get-a-single-commit
    def get_commit(project_id, sha, transforms)
      execute(:get, GET_COMMIT_URL.expand(project_id:, sha:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/projects.html#list-all-projects
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

    # https://docs.gitlab.com/ee/api/projects.html#add-project-hook
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

    # https://docs.gitlab.com/ee/api/projects.html#get-project-hook
    def find_webhook(project_id, hook_id, transforms)
      execute(:get, PROJECT_HOOK_URL.expand(project_id:, hook_id:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/branches.html#create-repository-branch
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
        json: {
          branch: new_branch_name,
          ref: ref
        }
      }

      raw_execute(:post, CREATE_BRANCH_URL.expand(project_id:).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/tags.html#create-a-new-tag
    def create_tag!(project_id, tag_name, branch_name)
      params = {
        form: {
          tag_name:,
          ref: branch_name
        }
      }

      execute(:post, CREATE_TAG_URL.expand(project_id:).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/merge_requests.html#create-merge-request
    def create_pr!(project_id, target_branch, source_branch, title, description, transforms)
      # gitlab allows creating merge requests without any changes, but we avoid it
      raise Installations::Error.new("Should not create a Pull Request without a diff", reason: :pull_request_without_commits) unless diff?(project_id, target_branch, source_branch)

      params = {
        json: {
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

    # https://docs.gitlab.com/ee/api/merge_requests.html#list-project-merge-requests
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

    # https://docs.gitlab.com/ee/api/merge_requests.html#get-single-merge-request
    def get_pr(project_id, pr_number, transforms)
      execute(:get, GET_MR_URL.expand(project_id:, merge_request_iid: pr_number).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/merge_requests.html#merge-a-merge-request
    def merge_pr!(project_id, pr_number, transforms)
      execute(:put, MR_MERGE_URL.expand(project_id:, merge_request_iid: pr_number).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/repositories.html#compare-branches-tags-or-commits
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

    # https://docs.gitlab.com/ee/api/repositories.html#compare-branches-tags-or-commits
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

    # https://docs.gitlab.com/ee/api/branches.html#get-single-repository-branch
    def branch_exists?(project_id, branch_name)
      get_branch(project_id, branch_name).present?
    end

    # https://docs.gitlab.com/ee/api/tags.html#get-a-single-repository-tag
    def tag_exists?(project_id, tag_name)
      execute(:get, GET_TAG_URL.expand(project_id:, tag_name:).to_s, {}).present?
    end

    # https://docs.gitlab.com/ee/api/branches.html#get-single-repository-branch
    def head(project_id, branch_name, sha_only: true, commit_transforms: nil)
      raise ArgumentError, "transforms must be supplied when querying head object" if !sha_only && !commit_transforms

      sha = get_branch(project_id, branch_name).dig("commit", "id")
      return sha if sha_only
      get_commit(project_id, sha, commit_transforms)
    end

    # https://docs.gitlab.com/ee/api/branches.html#get-single-repository-branch
    def get_branch(project_id, branch_name)
      execute(:get, GET_BRANCH_URL.expand(project_id:, branch_name:).to_s, {})
    end

    # https://docs.gitlab.com/ee/api/repository_files.html#get-file-from-repository
    def get_file_content(project_id, branch_name, file_path)
      response = execute(:get, GET_FILE_URL.expand(project_id:, file_path: file_path, ref: branch_name).to_s, {})
      return nil if response.nil? || response["content"].nil?
      Base64.decode64(response["content"])
    rescue ArgumentError
      raise Installations::Gitlab::Error.new("Invalid Base64 content in file", reason: :invalid_file_content)
    end

    # https://docs.gitlab.com/ee/api/repository_files.html#update-existing-file-in-repository
    def update_file!(project_id, branch_name, file_path, content, commit_message, author_name: nil, author_email: nil)
      params = {
        json: {
          branch: branch_name,
          content: content,
          commit_message: commit_message,
          author_name: author_name,
          author_email: author_email
        }.compact
      }

      raw_execute(:put, GET_FILE_URL.expand(project_id:, file_path: ERB::Util.url_encode(file_path)).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/releases.html#create-a-release
    def create_release!(project_id, tag_name, branch, description)
      params = {
        json: {
          tag_name: tag_name,
          ref: branch,
          description: description
        }
      }

      raw_execute(:post, CREATE_RELEASE_URL.expand(project_id:).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/merge_requests.html#merge-a-merge-request
    def enable_auto_merge(project_id, pr_number)
      params = {
        json: {
          should_remove_source_branch: true,
          merge_when_pipeline_succeeds: true
        }
      }

      raw_execute(:put, MR_MERGE_URL.expand(project_id:, merge_request_iid: pr_number).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#create-a-new-pipeline
    def run_pipeline!(project_id, branch_name, inputs, transforms)
      params = {
        json: {
          variables: inputs.map { |k, v| {key: k, value: v} }
        }
      }

      execute(:post, RUN_PIPELINE_URL.expand(project_id:, ref: branch_name).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#cancel-a-pipelines-jobs
    def cancel_pipeline!(project_id, pipeline_id)
      raw_execute(:post, CANCEL_PIPELINE_URL.expand(project_id:, pipeline_id:).to_s, {})
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#retry-jobs-in-a-pipeline
    def retry_pipeline!(project_id, pipeline_id)
      raw_execute(:post, RETRY_PIPELINE_URL.expand(project_id:, pipeline_id:).to_s, {})
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#get-a-single-pipeline
    def get_pipeline(project_id, pipeline_id, transforms)
      execute(:get, GET_PIPELINE_URL.expand(project_id:, pipeline_id:).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def create_annotated_tag!(project_id, tag_name, branch_name, message)
      params = {
        json: {
          tag_name: tag_name,
          ref: branch_name,
          message: message
        }
      }

      raw_execute(:post, CREATE_TAG_URL.expand(project_id:).to_s, params)
    end

    def assign_pr(project_id, pr_number, assignee_id)
      params = {
        json: {
          assignee_ids: [assignee_id]
        }
      }

      raw_execute(:put, GET_MR_URL.expand(project_id:, merge_request_iid: pr_number).to_s, params)
    end

    def cherry_pick_pr(project_id, pr_number, branch_name, patch_branch_name, commit_sha, transforms)
      create_branch!(project_id, branch_name, patch_branch_name)
      params = {
        json: {
          branch: patch_branch_name
        }
      }
      execute(:post, CHERRY_PICK_URL.expand(project_id:, sha: commit_sha).to_s, params)
      create_pr!(project_id, branch_name, patch_branch_name, "Cherry-pick #{commit_sha}", "", transforms)
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
