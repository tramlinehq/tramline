module Installations
  class Gitlab::Api
    require "down/http"

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
    GET_RELEASE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/releases/{tag_name}"
    RUN_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipeline{?ref}"
    LIST_PIPELINES_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines"
    GET_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}"
    CANCEL_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}/cancel"
    RETRY_PIPELINE_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}/retry"
    LIST_PIPELINE_JOBS_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/pipelines/{pipeline_id}/jobs"
    TRIGGER_JOB_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/jobs/{job_id}/play"
    CANCEL_JOB_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/jobs/{job_id}/cancel"
    RETRY_JOB_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/jobs/{job_id}/retry"
    GET_JOB_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/jobs/{job_id}"
    CHERRY_PICK_PR_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/merge_requests/{merge_request_iid}/cherry_pick"
    CHERRY_PICK_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/repository/commits/{sha}/cherry_pick"
    JOB_RUN_ARTIFACTS_URL = Addressable::Template.new "https://gitlab.com/api/v4/projects/{project_id}/jobs/{job_id}/artifacts"
    WEBHOOK_PERMISSIONS = {
      push_events: true,
      merge_requests_events: true
    }
    VALID_ARTIFACT_TYPES = %w[archive].freeze

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
          .then { |tokens| OpenStruct.new(tokens) }
      end

      def artifacts_url(project_id, job_id)
        JOB_RUN_ARTIFACTS_URL.expand(project_id:, job_id:).to_s
      end

      def filter_by_relevant_type(artifacts)
        artifacts.select { |artifact| VALID_ARTIFACT_TYPES.include? artifact["file_type"] }
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
    rescue Installations::Gitlab::Error => e
      raise e if e.reason != :not_found
      false
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
    def create_release!(project_id, tag_name, branch, release_notes)
      unless tag_exists?(project_id, tag_name)
        create_tag!(project_id, tag_name, branch)
      end

      params = {
        json: {
          tag_name: tag_name,
          description: release_notes
        }
      }

      execute(:post, CREATE_RELEASE_URL.expand(project_id:).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/merge_requests.html#merge-a-merge-request
    # This works a different from the other enable_auto_merge in other integrations.
    # Since this tries to merge again with the right flag because the auto_merge flag is not available in MR update API.
    def enable_auto_merge(project_id, pr_number)
      # check if PR is already merged
      pr_data = get_pr(project_id, pr_number, {state: :state})
      return if pr_data[:state] == "merged"

      params = {
        json: {
          should_remove_source_branch: true,
          auto_merge: true
        }
      }

      raw_execute(:put, MR_MERGE_URL.expand(project_id:, merge_request_iid: pr_number).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#create-a-new-pipeline
    def run_pipeline!(project_id, branch_name, inputs, transforms)
      processed_inputs = {
        versionCode: inputs[:version_code],
        versionName: inputs[:build_version],
        buildNotes: inputs[:build_notes]
      }.merge(inputs[:parameters] || {}).compact

      params = {
        json: {
          variables: processed_inputs.map { |k, v| {key: k, value: v} }
        }
      }

      execute(:post, RUN_PIPELINE_URL.expand(project_id: project_id, ref: branch_name).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/jobs.html#cancel-a-job
    def cancel_job!(project_id, job_id)
      raw_execute(:post, CANCEL_JOB_URL.expand(project_id: project_id, job_id: job_id).to_s, {})
    end

    # https://docs.gitlab.com/ee/api/jobs.html#retry-a-job
    def retry_job!(project_id, job_id, transforms)
      execute(:post, RETRY_JOB_URL.expand(project_id: project_id, job_id: job_id).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/jobs.html#get-a-single-job
    def get_job(project_id, job_id)
      execute(:get, GET_JOB_URL.expand(project_id: project_id, job_id: job_id).to_s, {})
        &.with_indifferent_access
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#list-project-pipelines
    def list_pipelines(project_id, transforms, max_results: 50)
      params = {
        params: {
          per_page: 50,
          order_by: "updated_at",
          sort: "desc"
        }
      }

      paginated_execute(:get, LIST_PIPELINES_URL.expand(project_id: project_id).to_s, params: params, max_results: max_results)
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    # https://docs.gitlab.com/ee/api/jobs.html#list-pipeline-jobs
    def list_pipeline_jobs(project_id, pipeline_id)
      transforms = {id: :id, name: :name, status: :status, stage: :stage}
      execute(:get, LIST_PIPELINE_JOBS_URL.expand(project_id: project_id, pipeline_id: pipeline_id).to_s, {})
        .then { |response| Installations::Response::Keys.transform(response, transforms) }
    end

    # https://docs.gitlab.com/ee/api/jobs.html#run-a-job
    def trigger_job!(project_id, job_id, transforms)
      execute(:post, TRIGGER_JOB_URL.expand(project_id: project_id, job_id: job_id).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#get-a-single-pipeline
    def get_pipeline(project_id, pipeline_id, transforms)
      execute(:get, GET_PIPELINE_URL.expand(project_id: project_id, pipeline_id: pipeline_id).to_s, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#cancel-a-pipeline
    def cancel_pipeline!(project_id, pipeline_id)
      raw_execute(:post, CANCEL_PIPELINE_URL.expand(project_id: project_id, pipeline_id: pipeline_id).to_s, {})
    end

    # https://docs.gitlab.com/ee/api/pipelines.html#retry-jobs-in-a-pipeline
    def retry_pipeline!(project_id, pipeline_id)
      raw_execute(:post, RETRY_PIPELINE_URL.expand(project_id: project_id, pipeline_id: pipeline_id).to_s, {})
    end

    # https://docs.gitlab.com/ee/api/tags.html#create-a-new-tag
    def create_annotated_tag!(project_id, tag_name, branch_name, message)
      params = {
        json: {
          tag_name: tag_name,
          ref: branch_name,
          message: message
        }
      }

      raw_execute(:post, CREATE_TAG_URL.expand(project_id: project_id).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/merge_requests.html#update-merge-request
    def assign_pr(project_id, pr_number, assignee_id)
      params = {
        json: {
          assignee_ids: [assignee_id]
        }
      }

      raw_execute(:put, GET_MR_URL.expand(project_id: project_id, merge_request_iid: pr_number).to_s, params)
    end

    # https://docs.gitlab.com/ee/api/commits.html#cherry-pick-a-commit
    def cherry_pick_pr(project_id, branch, commit_sha, patch_branch_name, pr_title_prefix, pr_description, transforms)
      create_branch!(project_id, branch, patch_branch_name)
      params = {
        json: {
          branch: patch_branch_name
        }
      }
      execute(:post, CHERRY_PICK_URL.expand(project_id: project_id, sha: commit_sha).to_s, params)
      create_pr!(project_id, branch, patch_branch_name, "#{pr_title_prefix} #{commit_sha}", pr_description, transforms)
    end

    def artifact_io_stream(url)
      download_url = fetch_redirect(url)
      return unless download_url
      Down::Http.download(download_url, follow: {max_hops: 1})
    end

    def find_existing_pipeline(project_id, branch_name, commit_sha, transforms)
      params = {
        params: {
          ref: branch_name,
          sha: commit_sha,
          per_page: 10,
          order_by: "updated_at",
          sort: "desc"
        }
      }

      pipelines = paginated_execute(:get, LIST_PIPELINES_URL.expand(project_id: project_id).to_s, params: params, max_results: 20)
      return nil if pipelines.empty?
      Installations::Response::Keys.transform(pipelines, transforms).first
    end

    JOB_NOT_FOUND = Installations::Error.new("GitLab Job not found", reason: :workflow_run_not_found)

    def run_pipeline_with_job!(project_id, branch_name, inputs, job_name, commit_sha, transforms)
      existing_pipeline = find_existing_pipeline(project_id, branch_name, commit_sha, transforms)

      if existing_pipeline
        job = trigger_specific_job_in_pipeline(project_id, existing_pipeline[:ci_ref], job_name, transforms)
        raise JOB_NOT_FOUND if job.blank?
        return job
      else
        pipeline = run_pipeline!(project_id, branch_name, inputs, transforms)
        if job_name.present? && job_name != "default"
          job = trigger_specific_job_in_pipeline(project_id, pipeline[:ci_ref], job_name, transforms)
          raise JOB_NOT_FOUND if job.blank?
          return job
        end
      end

      raise JOB_NOT_FOUND
    end

    def trigger_specific_job_in_pipeline(project_id, pipeline_id, job_name, transforms)
      jobs = list_pipeline_jobs(project_id, pipeline_id)
      target_job = jobs.find { |job| job[:name] == job_name }
      raise JOB_NOT_FOUND unless target_job
      trigger_job!(project_id, target_job[:id], transforms)
    end

    def list_jobs_from_gitlab_ci(project_id, branch_name = "main")
      yaml_content = get_file_content(project_id, branch_name, ".gitlab-ci.yml")
      return [] if yaml_content.nil?

      pipeline_config = YAML.safe_load(yaml_content, aliases: true)
      jobs = []

      excluded_keys = %w[stages variables before_script after_script].freeze
      pipeline_config.each do |key, value|
        next if key.start_with?(".") || excluded_keys.include?(key)
        next unless value.is_a?(Hash)

        jobs << {id: key, name: key}
      end

      jobs
    rescue YAML::SyntaxError, ArgumentError => e
      Rails.logger.warn "Failed to parse .gitlab-ci.yml: #{e.message}"
      []
    rescue Installations::Error => e
      Rails.logger.warn "Failed to fetch .gitlab-ci.yml: #{e.message}"
      []
    end

    private

    def fetch_redirect(url)
      response = raw_execute(:get, url, {})
      response.headers["Location"]
    end

    def execute(verb, url, params)
      response = raw_execute(verb, url, params)
      JSON.parse(response.body.to_s)
    end

    def raw_execute(verb, url, params)
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)
      raise Installations::Gitlab::Error.new({"error" => "Service Unavailable"}) if response.status.server_error?
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
