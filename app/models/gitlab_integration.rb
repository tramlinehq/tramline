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
    rescue Installations::Errors::ResourceNotFound
      create_webhook!(train_id:)
    end
  end

  def create_webhook!(url_params)
    with_api_retries { installation.create_project_webhook!(code_repository_name, events_url(url_params), WEBHOOK_TRANSFORMATIONS) }
  end

  def create_tag!(tag_name, branch)
    with_api_retries { installation.create_tag!(code_repository_name, tag_name, branch) }
  end

  def create_branch!(from, to)
    with_api_retries { installation.create_branch!(code_repository_name, from, to) }
  end

  def metadata
    installation.user_info(USER_INFO_TRANSFORMATIONS)
  end

  def branch_url(repo, branch_name)
    "https://gitlab.com/#{repo}/tree/#{branch_name}"
  end

  def tag_url(repo, tag_name)
    "https://gitlab.com/#{repo}/-/tags/#{tag_name}"
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

  def connection_data
    return unless integration.metadata
    "#{integration.metadata["name"]} (#{integration.metadata["username"]})"
  end

  COMMIT_TRANSFORMATIONS = {
    commit_sha: :id,
    author_email: :author_email,
    author_name: :author_name,
    message: :message,
    url: :web_url,
    timestamp: :authored_date
  }

  def get_commit(sha)
    with_api_retries { installation.get_commit(app_config.code_repository["id"], sha, COMMIT_TRANSFORMATIONS) }
  end

  PR_TRANSFORMATIONS = {
    source_id: :id,
    number: :iid,
    title: :title,
    body: :description,
    url: :web_url,
    state: :state,
    head_ref: :sha,
    base_ref: :sha,
    opened_at: :created_at
  }

  def create_pr!(to_branch_ref, from_branch_ref, title, description)
    with_api_retries { installation.create_pr!(app_config.code_repository_name, to_branch_ref, from_branch_ref, title, description) }
  end

  def find_pr(to_branch_ref, from_branch_ref)
    with_api_retries { installation.find_pr(app_config.code_repository_name, to_branch_ref, from_branch_ref) }
  end

  def get_pr(pr_number)
    with_api_retries { installation.get_pr(app_config.code_repository_name, pr_number, PR_TRANSFORMATIONS) }
  end

  def merge_pr!(pr_number)
    with_api_retries { installation.merge_pr!(app_config.code_repository_name, pr_number) }
  end

  private

  # retry once (2 attempts in total)
  def with_api_retries
    retryables = [Installations::Gitlab::Api::TokenExpired]
    Retryable.retryable(on: retryables, tries: 2, sleep: 0, exception_cb: proc { reset_tokens! }) { yield }
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
