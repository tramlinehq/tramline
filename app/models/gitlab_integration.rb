# == Schema Information
#
# Table name: gitlab_integrations
#
#  id                           :uuid             not null, primary key
#  oauth_access_token           :string
#  oauth_refresh_token          :string
#  original_oauth_access_token  :string
#  original_oauth_refresh_token :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
class GitlabIntegration < ApplicationRecord
  has_paper_trail
  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers
  using RefinedHash

  attr_accessor :code
  before_create :complete_access
  delegate :code_repository_name, :code_repo_namespace, :working_branch, to: :app_config
  delegate :cache, to: Rails

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://gitlab.com/oauth/authorize{?params*}")
  EitherTransformation = Installations::Response::Keys::Either

  REPOS_TRANSFORMATIONS = {
    id: :id,
    name: :path,
    namespace: [:namespace, :path],
    full_name: :path_with_namespace,
    description: :description,
    repo_url: :web_url,
    avatar_url: :avatar_url
  }

  WEBHOOK_TRANSFORMATIONS = {
    id: :id,
    url: :url,
    push_events: :push_events
  }

  USER_INFO_TRANSFORMATIONS = {
    id: :id,
    username: :username,
    name: :name,
    avatar_url: :avatar_url
  }

  COMMITS_TRANSFORMATIONS = {
    url: :web_url,
    commit_hash: :id,
    message: :message,
    author_name: :author_name,
    author_email: :author_email,
    timestamp: :authored_date
  }

  COMMITS_HOOK_TRANSFORMATIONS = {
    url: :url,
    commit_hash: :id,
    message: :message,
    author_name: [:author, :name],
    author_email: [:author, :email],
    author_login: [:author, :username],
    timestamp: :timestamp
  }

  COMMITS_BETWEEN_TRANSFORMATIONS = {
    url: :web_url,
    commit_hash: :id,
    message: :title,
    author_name: :author_name,
    author_email: :author_email,
    timestamp: :created_at
  }

  PR_TRANSFORMATIONS = {
    source_id: :id,
    number: :iid,
    title: :title,
    body: :description,
    url: :web_url,
    state: :state,
    head_ref: :source_branch,
    base_ref: :target_branch,
    opened_at: :created_at,
    closed_at: EitherTransformation.new(:closed_at, :merged_at),
    merge_commit_sha: EitherTransformation.new(:merge_commit_sha, :squash_commit_sha)
  }

  WEBHOOK_PR_TRANSFORMATIONS = {
    source_id: :id,
    number: :iid,
    title: :title,
    body: :description,
    url: :url,
    state: :state,
    head_ref: :source_branch,
    base_ref: :target_branch,
    opened_at: :created_at,
    closed_at: :updated_at,
    merge_commit_sha: [:last_commit, :id] # FIXME: this is not correct, we might need to fetch this, just stubbing this for now.
  }

  def install_path
    BASE_INSTALLATION_URL
      .expand(params: {
        client_id: creds.integrations.gitlab.client_id,
        redirect_uri: redirect_uri,
        response_type: :code,
        scope: creds.integrations.gitlab.scopes,
        state: integration.installation_state
      }).to_s
  end

  def complete_access
    return if oauth_access_token.present? && oauth_refresh_token.present?
    set_tokens(Installations::Gitlab::Api.oauth_access_token(code, redirect_uri))
  end

  def workspaces = nil

  def repos(_)
    with_api_retries { installation.list_projects(REPOS_TRANSFORMATIONS) }
  end

  WORKFLOW_RUN_TRANSFORMATIONS = {
    ci_ref: :id,
    ci_link: :web_url,
    number: :id,
    unique_number: :id
  }

  WORKFLOWS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  GITLAB_CI_GLOBAL_KEYWORDS = %w[
    default include stages workflow variables spec
    image services before_script after_script cache
  ].freeze

  def workflows(branch_name = "main", bust_cache: false)
    Rails.cache.delete(workflows_cache_key(branch_name)) if bust_cache

    cache.fetch(workflows_cache_key(branch_name), expires_in: 120.minutes) do
      parse_gitlab_ci_jobs(branch_name)
    end
  rescue Installations::Error
    []
  end

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil, _deploy_action_enabled = false)
    with_api_retries do
      installation.run_pipeline!(code_repository_name, branch_name, inputs, WORKFLOW_RUN_TRANSFORMATIONS)
    end
  end

  def cancel_workflow_run!(ci_ref)
    with_api_retries { installation.cancel_pipeline!(code_repository_name, ci_ref) }
  end

  def retry_workflow_run!(ci_ref)
    with_api_retries { installation.retry_pipeline!(code_repository_name, ci_ref) }
  end

  def find_workflow_run(workflow_id, branch, commit_sha)
    # GitLab does not have a direct equivalent to finding a workflow run by workflow_id, branch, and commit_sha.
    # It's more common to list pipelines and filter them.
    # For now, we'll raise an unsupported action.
    raise Integrations::UnsupportedAction
  end

  def get_workflow_run(pipeline_id)
    with_api_retries { installation.get_pipeline(code_repository_name, pipeline_id, WORKFLOW_RUN_TRANSFORMATIONS) }
  end

  ARTIFACTS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    size_in_bytes: :size,
    archive_download_url: :file_location,
    generated_at: :created_at
  }

  def get_artifact(_, _, external_workflow_run_id:)
    raise Integrations::UnsupportedAction
  end

  def artifact_url
    raise Integrations::UnsupportedAction
  end

  def workflow_retriable?
    false
  end

  def further_setup?
    false
  end

  def enable_auto_merge? = false

  def find_or_create_webhook!(id:, train_id:)
    GitHub::Result.new do
      if id
        webhook = with_api_retries { installation.find_webhook(code_repository_name, id, WEBHOOK_TRANSFORMATIONS) }

        if webhook[:url] == events_url(train_id:) && installation.class::WEBHOOK_PERMISSIONS.keys.all? { |k| webhook[k] }
          webhook
        else
          create_webhook!(train_id:)
        end
      else
        create_webhook!(train_id:)
      end
    rescue Installations::Error => ex
      raise ex unless ex.reason == :not_found
      create_webhook!(train_id:)
    end
  end

  def create_webhook!(url_params)
    with_api_retries { installation.create_project_webhook!(code_repository_name, events_url(url_params), WEBHOOK_TRANSFORMATIONS) }
  end

  def create_release!(tag_name, branch, _, _)
    with_api_retries { installation.create_tag!(code_repository_name, tag_name, branch) }
  end

  def create_tag!(tag_name, sha)
    with_api_retries { installation.create_tag!(code_repository_name, tag_name, sha) }
  end

  def create_branch!(from, to, source_type: :branch)
    with_api_retries { installation.create_branch!(code_repository_name, from, to, source_type:) }
  end

  def metadata
    installation.user_info(USER_INFO_TRANSFORMATIONS)
  end

  def pull_requests_url(branch_name, open: false)
    state = open ? "opened" : "all"
    q = URI.encode_www_form("state" => state, "target_branch" => branch_name)
    "https://gitlab.com/#{code_repository_name}/-/merge_requests?#{q}"
  end

  def branch_url(branch_name)
    "https://gitlab.com/#{code_repository_name}/tree/#{branch_name}"
  end

  def tag_url(tag_name)
    "https://gitlab.com/#{code_repository_name}/-/tags/#{tag_name}"
  end

  def compare_url(to_branch, from_branch)
    "https://gitlab.com/#{code_repository_name}/-/compare/#{to_branch}...#{from_branch}?straight=true"
  end

  def installation
    Installations::Gitlab::Api.new(oauth_access_token)
  end

  def to_s
    "gitlab"
  end

  def creatable?
    false
  end

  def connectable?
    true
  end

  def store?
    false
  end

  def project_link = nil

  def connection_data
    return unless integration.metadata
    "Organization: #{integration.metadata["name"]} (#{integration.metadata["username"]})"
  end

  def get_commit(sha)
    with_api_retries { installation.get_commit(app_config.code_repository["id"], sha, COMMITS_TRANSFORMATIONS) }
  end

  def create_pr!(to_branch_ref, from_branch_ref, title, description)
    with_api_retries { installation.create_pr!(code_repository_name, to_branch_ref, from_branch_ref, title, description, PR_TRANSFORMATIONS).merge_if_present(source: :gitlab) }
  end

  def find_pr(to_branch_ref, from_branch_ref)
    with_api_retries { installation.find_pr(code_repository_name, to_branch_ref, from_branch_ref, PR_TRANSFORMATIONS).merge_if_present(source: :gitlab) }
  end

  def get_pr(pr_number)
    with_api_retries { installation.get_pr(code_repository_name, pr_number, PR_TRANSFORMATIONS).merge_if_present(source: :gitlab) }
  end

  def merge_pr!(pr_number)
    with_api_retries { installation.merge_pr!(code_repository_name, pr_number, PR_TRANSFORMATIONS).merge_if_present(source: :gitlab) }
  end

  def commit_log(from_branch, to_branch)
    with_api_retries { installation.commits_between(code_repository_name, from_branch, to_branch, COMMITS_BETWEEN_TRANSFORMATIONS) }
  end

  def diff_between?(from_branch, to_branch, _)
    with_api_retries { installation.diff?(code_repository_name, from_branch, to_branch) }
  end

  def create_patch_pr!(to_branch, patch_branch, commit_hash, pr_title_prefix, pr_description = "")
    with_api_retries do
      installation
        .cherry_pick_pr(code_repository_name, working_branch, commit_hash, patch_branch, pr_title_prefix, pr_description, PR_TRANSFORMATIONS)
        .merge_if_present(source: :gitlab)
    end
  end

  def enable_auto_merge!(pr_number)
    with_api_retries { installation.enable_auto_merge(code_repository_name, pr_number) }
  end

  def public_icon_img
    "https://storage.googleapis.com/tramline-public-assets/gitlab_small.png".freeze
  end

  def branch_head_sha(branch, sha_only: true)
    with_api_retries { installation.head(code_repository_name, branch, sha_only:, commit_transforms: COMMITS_TRANSFORMATIONS) }
  end

  def get_file_content(branch_name, file_path)
    with_api_retries { installation.get_file_content(code_repository_name, branch_name, file_path) }
  end

  def update_file!(branch_name, file_path, content, commit_message, author_name: nil, author_email: nil)
    with_api_retries { installation.update_file!(code_repository_name, branch_name, file_path, content, commit_message, author_name:, author_email:) }
  end

  def branch_exists?(branch)
    with_api_retries { installation.branch_exists?(code_repository_name, branch) }
  rescue Installations::Error => ex
    raise ex unless ex.reason == :not_found
    false
  end

  def tag_exists?(tag_name)
    with_api_retries { installation.tag_exists?(code_repository_name, tag_name) }
  rescue Installations::Error => ex
    raise ex unless ex.reason == :not_found
    false
  end

  def bot_name
    "gitlab-bot"
  end

  def pr_closed?(pr)
    %w[closed merged].include?(pr[:state])
  end

  def pr_open?(pr)
    %w[opened locked].include?(pr[:state])
  end

  private

  # retry once (2 attempts in total)
  MAX_RETRY_ATTEMPTS = 2
  RETRYABLE_ERRORS = []

  def with_api_retries(attempt: 0, &)
    yield
  rescue Installations::Gitlab::Error => ex
    raise ex if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if ex.reason == :token_expired
      reset_tokens!
      return with_api_retries(attempt: next_attempt, &)
    end

    if RETRYABLE_ERRORS.include?(ex.reason)
      return with_api_retries(attempt: next_attempt, &)
    end

    raise ex
  end

  def reset_tokens!
    set_tokens(Installations::Gitlab::Api.oauth_refresh_token(oauth_refresh_token, redirect_uri))
    save!
  end

  def set_tokens(tokens)
    assign_attributes(oauth_access_token: tokens.access_token, oauth_refresh_token: tokens.refresh_token) if tokens
  end

  def app_config
    integration.integrable.config
  end

  def redirect_uri
    if Rails.env.development?
      gitlab_callback_url(host: ENV["HOST_NAME"], port: "3000", protocol: "https")
    else
      gitlab_callback_url(host: ENV["HOST_NAME"], protocol: "https")
    end
  end

  def events_url(params)
    if Rails.env.development?
      gitlab_events_url(host: ENV["WEBHOOK_HOST_NAME"], **params)
    else
      gitlab_events_url(host: ENV["HOST_NAME"], protocol: "https", **params)
    end
  end

  def workflows_cache_key(branch_name = "main")
    "app/#{integrable.id}/gitlab_integration/#{id}/workflows/#{branch_name}"
  end

  def parse_gitlab_ci_jobs(branch_name)
    yaml_content = with_api_retries { installation.get_file_content(code_repository_name, branch_name, ".gitlab-ci.yml") }
    return [] if yaml_content.nil?

    ci_config = YAML.safe_load(yaml_content, aliases: true)
    return [] unless ci_config.is_a?(Hash)

    jobs = ci_config.reject { |key, _| GITLAB_CI_GLOBAL_KEYWORDS.include?(key.to_s) || key.to_s.start_with?(".") }
    jobs.map { |job_name, _| {id: job_name, name: job_name} }
  rescue YAML::Exception => e
    raise Installations::Error.new("Failed to parse .gitlab-ci.yml: #{e.message}", reason: :gitlab_ci_parse_error)
  rescue => e
    raise Installations::Error.new("Failed to fetch .gitlab-ci.yml: #{e.message}", reason: :gitlab_ci_not_found)
  end
end
