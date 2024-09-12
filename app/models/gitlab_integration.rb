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

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://gitlab.com/oauth/authorize{?params*}")

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
    opened_at: :created_at
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
    opened_at: :created_at
  }

  def install_path
    unless integration.version_control? || integration.ci_cd?
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end

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
    set_tokens(Installations::Gitlab::Api.oauth_access_token(code, redirect_uri))
  end

  def repos
    with_api_retries { installation.list_projects(REPOS_TRANSFORMATIONS) }
  end

  def workflows
    nil
  end

  def further_setup?
    return true if integration.version_control?
    false
  end

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

  def create_release!(tag_name, branch)
    with_api_retries { installation.create_tag!(code_repository_name, tag_name, branch) }
  end

  def create_tag!(tag_name, sha)
    # FIXME
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
    with_api_retries { installation.merge_pr!(code_repository_name, pr_number) }
  end

  def commit_log(from_branch, to_branch)
    with_api_retries { installation.commits_between(code_repository_name, from_branch, to_branch, COMMITS_BETWEEN_TRANSFORMATIONS) }
  end

  def diff_between?(from_branch, to_branch, _)
    with_api_retries { installation.diff?(code_repository_name, from_branch, to_branch) }
  end

  def create_patch_pr!(to_branch, patch_branch, commit_hash, pr_title_prefix)
    # FIXME
    {}.merge_if_present(source: :gitlab)
  end

  def enable_auto_merge!(pr_number)
    # FIXME
  end

  def public_icon_img
    "https://storage.googleapis.com/tramline-public-assets/gitlab_small.png".freeze
  end

  def branch_head_sha(branch, sha_only: true)
    with_api_retries { installation.head(code_repository_name, branch, sha_only:, commit_transforms: COMMITS_TRANSFORMATIONS) }
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
    nil
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
    integration.app.config
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
end
