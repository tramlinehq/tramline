class GitlabIntegration < ApplicationRecord
  has_paper_trail
  # encrypts :oauth_access_token, deterministic: true

  include Vaultable
  include Providable
  include Rails.application.routes.url_helpers

  attr_accessor :code
  before_create :complete_access
  delegate :code_repository_name, to: :app_config

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://gitlab.com/oauth/authorize{?params*}")

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
    with_api_retries { installation.list_projects }
  end

  def workflows
    # with_api_retries { installation.list_pipelines(code_repository_name) }
  end

  def create_webhook!(url_params)
    with_api_retries { installation.create_project_webhook!(code_repository_name, events_url(url_params)) }
  end

  def create_tag!(tag_name, branch)
    with_api_retries { installation.create_tag!(code_repository_name, tag_name, branch) }
  end

  # @return [Installation::Gitlab::Api]
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

  private

  def with_api_retries
    # retry just once (2 attempts in total)
    Retryable.retryable(on: Installations::Gitlab::Api::TokenExpired, tries: 2, sleep: 0, exception_cb: proc { reset_tokens! }) do
      yield
    end
  end

  def reset_tokens!
    set_tokens(Installations::Gitlab::Api.oauth_refresh_token(oauth_refresh_token, redirect_uri))
    save!
  end

  def set_tokens(tokens)
    if tokens
      self.oauth_access_token = tokens.access_token
      self.oauth_refresh_token = tokens.refresh_token
    end
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
