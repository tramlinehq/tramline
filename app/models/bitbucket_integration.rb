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
  delegate :code_repo_name_only, to: :app_config

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
    Installations::Bitbucket::Api.new(oauth_access_token, workspace)
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

  WORKSPACE_TRANSFORMATIONS = {
    id: :slug,
    name: :name
  }

  def workspaces
    with_api_retries { installation.list_workspaces(WORKSPACE_TRANSFORMATIONS) }
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

  WEBHOOK_TRANSFORMATIONS = {
    id: :uuid,
    url: :url,
    events: :events
  }

  PR_TRANSFORMATIONS = {
    source_id: :id,
    number: :id,
    title: :title,
    body: :description,
    url: [:links, :html, :href],
    state: :state,
    head_ref: [:source, :branch, :name],
    base_ref: [:destination, :branch, :name],
    opened_at: :created_on
  }

  COMMITS_TRANSFORMATIONS = {
    url: [:links, :html, :href],
    commit_hash: :hash,
    message: :message,
    # TODO: author information is not available when user does
    # not match on atlassian
    author_name: [:author, :user, :display_name],
    # TODO: email is not available
    author_email: :author_email,
    timestamp: :date,
    parents: {
      parents: {
        url: [:links, :html, :href],
        sha: [:hash]
      }
    }
  }

  def repos
    with_api_retries { installation.list_repos(REPOS_TRANSFORMATIONS) }
  end

  # CI/CD

  WORKFLOWS_TRANSFORMATIONS = {
    id: :uuid,
    name: :name
  }

  WORKFLOW_RUN_TRANSFORMATIONS = {
    ci_ref: :uuid,
    number: :build_number
  }

  ARTIFACTS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    size_in_bytes: :size,
    archive_download_url: [:links, :self, :href],
    generated_at: :created_at
  }

  def workflows
    return [] unless integration.ci_cd?
    with_api_retries { installation.list_pipelines(code_repo_name_only, WORKFLOWS_TRANSFORMATIONS) }
  end

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil)
    with_api_retries do
      res = installation.run_workflow!(code_repo_name_only, ci_cd_channel, branch_name, inputs, commit_hash, WORKFLOW_RUN_TRANSFORMATIONS)
      res.merge(ci_link: "https://bitbucket.org/#{workspace}/#{code_repo_name_only}/pipelines/results/#{res[:number]}")
    end
  end

  def cancel_workflow_run!(ci_ref)
    installation.cancel_workflow!(code_repo_name_only, ci_ref)
  end

  def find_workflow_run(_workflow_id, _branch, _commit_sha)
    raise Integrations::UnsupportedAction
  end

  def get_workflow_run(pipeline_id)
    installation.get_pipeline(code_repo_name_only, pipeline_id)
  end

  def get_artifact_v2(_, artifact_name)
    raise Integration::NoBuildArtifactAvailable if artifact_name.blank?

    artifact = with_api_retries { installation.get_file(code_repo_name_only, artifact_name, ARTIFACTS_TRANSFORMATIONS) }
    raise Integration::NoBuildArtifactAvailable if artifact.blank?

    Rails.logger.info "Downloading artifact #{artifact}"
    stream = with_api_retries { installation.download_artifact(artifact[:archive_download_url]) }
    {artifact:, stream: Artifacts::Stream.new(stream)}
  end

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

  def events_url(params)
    if Rails.env.development?
      bitbucket_events_url(host: ENV["WEBHOOK_HOST_NAME"], **params)
    else
      bitbucket_events_url(host: ENV["HOST_NAME"], protocol: "https", **params)
    end
  end

  def workspace
    "tramline"
  end
end
