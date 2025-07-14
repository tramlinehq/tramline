# == Schema Information
#
# Table name: gitlab_integrations
#
#  id                  :uuid             not null, primary key
#  oauth_access_token  :string
#  oauth_refresh_token :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class GitlabIntegration < ApplicationRecord
  has_paper_trail
  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  include Linkable
  include Vaultable
  include Providable
  include Displayable
  using RefinedHash
  using RefinedArray

  attr_accessor :code
  before_validation :complete_access, if: :new_record?
  delegate :integrable, to: :integration
  delegate :organization, to: :integrable
  delegate :code_repository_name, :code_repo_namespace, to: :app_config
  delegate :cache, to: Rails
  validate :correct_key, on: :create

  API = Installations::Gitlab::Api
  BASE_INSTALLATION_URL = Addressable::Template.new("https://gitlab.com/oauth/authorize{?params*}")
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
    url: :url
  }.merge(API::WEBHOOK_PERMISSIONS.keys.zip_map_self)

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
    # TODO: add parents
  }

  COMMITS_HOOK_TRANSFORMATIONS = {
    url: :url,
    commit_hash: :id,
    message: :message,
    author_name: [:author, :name],
    author_email: [:author, :email],
    author_login: [:author, :username],
    timestamp: :timestamp
    # TODO: add parents
  }

  COMMITS_BETWEEN_TRANSFORMATIONS = {
    url: :web_url,
    commit_hash: :id,
    message: :title,
    author_name: :author_name,
    author_email: :author_email,
    timestamp: :created_at
    # TODO: add parents
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
    # TODO: add labels
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
    merge_commit_sha: EitherTransformation.new(:merge_commit_sha, :squash_commit_sha)
    # TODO: add labels
  }

  WORKFLOW_RUN_TRANSFORMATIONS = {
    ci_ref: :id,
    ci_link: :web_url,
    number: :id,
    unique_number: :id
  }

  WORKFLOWS_TRANSFORMATIONS = {
    id: :name,
    name: :name
  }

  PIPELINE_TRANSFORMATIONS = {
    id: :id,
    status: :status,
    ref: :ref,
    created_at: :created_at
  }

  JOB_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    status: :status,
    stage: :stage
  }

  JOB_RUN_TRANSFORMATIONS = {
    ci_ref: :id,
    ci_link: :web_url,
    number: :id,
    unique_number: :id
  }

  ARTIFACTS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    size_in_bytes: :size,
    archive_download_url: :file_location,
    generated_at: :created_at
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
    set_tokens(API.oauth_access_token(code, redirect_uri))
  end

  def correct_key
    if integration.ci_cd?
      errors.add(:base, :workflows) if workflows.blank?
    elsif integration.version_control?
      errors.add(:base, :repos) if repos.blank?
    end
  end

  def workspaces = nil

  def repos(_ = nil)
    with_api_retries { installation.list_projects(REPOS_TRANSFORMATIONS) }
  end

  def workflows(branch_name = "main", bust_cache: false)
    Rails.cache.delete(workflows_cache_key(branch_name)) if bust_cache
    cache.fetch(workflows_cache_key(branch_name), expires_in: 120.minutes) do
      with_api_retries { installation.list_jobs_from_gitlab_ci(code_repository_name, branch_name) }
    end
  rescue Installations::Error
    []
  end

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil, _deploy_action_enabled = false)
    with_api_retries do
      if ci_cd_channel.present? && ci_cd_channel != "default"
        installation.run_pipeline_with_job!(code_repository_name, branch_name, inputs, ci_cd_channel, commit_hash, WORKFLOW_RUN_TRANSFORMATIONS)
      else
        installation.run_pipeline!(code_repository_name, branch_name, inputs, WORKFLOW_RUN_TRANSFORMATIONS)
      end
    end
  end

  def cancel_workflow_run!(ci_ref)
    with_api_retries { installation.cancel_job!(code_repository_name, ci_ref) }
  end

  def retry_workflow_run!(ci_ref)
    with_api_retries { installation.retry_job!(code_repository_name, ci_ref, JOB_RUN_TRANSFORMATIONS) }
  end

  def find_workflow_run(_, _, _)
    # GitLab does not have a direct equivalent to finding a workflow run by workflow_id, branch, and commit_sha.
    # When a job is triggered, we have an ID which we can directly find later (see: get_workflow_run).
    raise Integrations::UnsupportedAction
  end

  def get_workflow_run(job_id)
    with_api_retries { installation.get_job(code_repository_name, job_id) }
  end

  def get_artifact(artifact_url, artifact_name_pattern, _)
    artifact_not_found = Installations::Error.new("Could not find the artifact", reason: :artifact_not_found)
    raise artifact_not_found if artifact_url.blank?

    artifact_stream =
      with_api_retries do
        installation
          .artifact_io_stream(artifact_url)
          .tap { |zip_file| raise artifact_not_found if zip_file.blank? }
          .then { |zip_file| Artifacts::Stream.new(zip_file, is_archive: true, filter_pattern: artifact_name_pattern) }
      end

    artifact_params = {
      name: artifact_name_pattern,
      size_in_bytes: artifact_stream.archive_size_in_bytes
    }

    {artifact: artifact_params, stream: artifact_stream}
  end

  def artifacts_url(job_id, artifacts_payload)
    return if API.filter_by_relevant_type(artifacts_payload).blank?
    API.artifacts_url(code_repository_name, job_id)
  end

  def workflow_retriable? = true

  def workflow_retriable_in_place? = false

  def further_setup?
    false
  end

  def enable_auto_merge? = true

  def find_or_create_webhook!(id:, train_id:)
    GitHub::Result.new do
      if id
        webhook = with_api_retries { installation.find_webhook(code_repository_name, id, WEBHOOK_TRANSFORMATIONS) }
        if webhook[:url] == events_url(train_id:) && API::WEBHOOK_PERMISSIONS.keys.all? { |k| webhook[k] }
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

  def create_release!(tag_name, branch, _, release_notes)
    with_api_retries { installation.create_release!(code_repository_name, tag_name, branch, release_notes) }
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
    API.new(oauth_access_token)
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
        .cherry_pick_pr(code_repository_name, to_branch, commit_hash, patch_branch, pr_title_prefix, pr_description, PR_TRANSFORMATIONS)
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

  def set_tokens(tokens)
    assign_attributes(oauth_access_token: tokens.access_token, oauth_refresh_token: tokens.refresh_token)
  end

  private

  # 21 attempts in total
  MAX_RETRY_ATTEMPTS = 20
  RETRYABLE_ERRORS = [:workflow_run_not_runnable]

  def with_api_retries(attempt: 0, &)
    yield
  rescue Installations::Gitlab::Error => ex
    raise ex if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if ex.reason == :token_expired
      reset_tokens!
      sleep 0.3
      return with_api_retries(attempt: next_attempt, &)
    end

    if RETRYABLE_ERRORS.include?(ex.reason)
      sleep 0.3
      return with_api_retries(attempt: next_attempt, &)
    end

    raise ex
  end

  def reset_tokens!
    tokens = API.oauth_refresh_token(oauth_refresh_token, redirect_uri)

    if tokens.nil? || tokens.access_token.blank? || tokens.refresh_token.blank?
      raise Installations::Gitlab::Error.new("error" => "token_refresh_failure")
    end

    # ensure that all gitlab integrations are updated with the new tokens (not just self)
    transaction do
      affiliated_providers.each do |affiliated_provider|
        affiliated_provider.set_tokens(tokens)
        affiliated_provider.save!
      end
    end

    reload
  end

  def app_config
    integrable.config
  end

  def redirect_uri
    gitlab_callback_url(link_params)
  end

  def events_url(params)
    gitlab_events_url(**tunneled_link_params, **params)
  end

  def workflows_cache_key(branch_name = "main")
    "app/#{integrable.id}/gitlab_integration/#{id}/pipeline_jobs/#{branch_name}"
  end

  def affiliated_providers
    integrable.integrations.connected.gitlab_integrations.map(&:providable)
  end
end
