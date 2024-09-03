# == Schema Information
#
# Table name: bitbucket_integrations
#
#  id                  :uuid             not null, primary key
#  oauth_access_token  :string
#  oauth_refresh_token :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class BitbucketIntegration < ApplicationRecord
  has_paper_trail
  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://bitbucket.org/site/oauth2/authorize{?params*}")

  attr_accessor :code
  before_create :complete_access
  delegate :code_repository_name, :code_repo_namespace, :working_branch, to: :app_config

  def install_path
    unless integration.version_control? || integration.ci_cd?
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end

    BASE_INSTALLATION_URL
      .expand(params: {
        client_id: creds.integrations.bitbucket.client_id,
        redirect_uri: redirect_uri,
        response_type: :code,
        state: integration.installation_state
      }).to_s
  end

  def complete_access
    set_tokens(Installations::Bitbucket::Api.oauth_access_token(code, redirect_uri))
  end

  def installation
    Installations::Bitbucket::Api.new(oauth_access_token, "tramline")
  end

  def to_s
    "bitbucket"
  end

  def creatable?
    false
  end

  def connectable?
    true
  end

  def connection_data
    return unless integration.metadata
    "Organization: #{integration.metadata["account_name"]} (#{integration.metadata["account_id"]})"
  end

  def further_setup?
    return true if integration.version_control?
    false
  end

  # VCS

  REPOS_TRANSFORMATIONS = {
    id: :slug,
    name: :name,
    namespace: [:workspace, :slug],
    full_name: :full_name,
    description: :description,
    repo_url: [:links, :html],
    avatar_url: [:links, :avatar]
  }

  def repos
    with_api_retries { installation.list_repos(REPOS_TRANSFORMATIONS) }
  end

  # CI/CD

  private

  MAX_RETRY_ATTEMPTS = 2
  RETRYABLE_ERRORS = []

  def with_api_retries(attempt: 0, &block)
    yield
  rescue Installations::Bitbucket::Error => ex
    raise ex if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if ex.reason == :token_expired
      reset_tokens!
      return with_api_retries(attempt: next_attempt, &block)
    end

    if RETRYABLE_ERRORS.include?(ex.reason)
      return with_api_retries(attempt: next_attempt, &block)
    end

    raise ex
  end

  def reset_tokens!
    set_tokens(Installations::Bitbucket::Api.oauth_refresh_token(oauth_refresh_token, redirect_uri))
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
      bitbucket_callback_url(host: ENV["HOST_NAME"], port: "3000", protocol: "https")
    else
      bitbucket_callback_url(host: ENV["HOST_NAME"], protocol: "https")
    end
  end
end
