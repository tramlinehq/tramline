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
  using RefinedHash
  include Linkable
  include Vaultable
  include Providable
  include Displayable

  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://bitbucket.org/site/oauth2/authorize{?params*}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/bitbucket_small.png".freeze

  attr_accessor :code
  before_create :complete_access
  delegate :app, to: :integration
  delegate :code_repository_name, to: :app_config
  delegate :cache, to: Rails

  def install_path
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
    Installations::Bitbucket::Api.new(oauth_access_token)
  end

  def to_s = "bitbucket"

  def creatable? = false

  def connectable? = true

  def store? = false

  def project_link = nil

  def further_setup? = false

  def cherry_picks_allowed? = false

  def public_icon_img
    PUBLIC_ICON
  end

  WORKSPACE_TRANSFORMATIONS = {
    id: :slug,
    name: :name
  }

  USER_INFO_TRANSFORMATIONS = {
    id: :uuid,
    username: :username,
    name: :display_name,
    avatar_url: [:links, :avatar, :href]
  }

  def workspaces
    with_api_retries { installation.list_workspaces(WORKSPACE_TRANSFORMATIONS).pluck(:id) }
  end

  def metadata
    with_api_retries { installation.user_info(USER_INFO_TRANSFORMATIONS) }
  end

  def connection_data
    return unless integration.metadata
    "Added by user: #{integration.metadata["name"]} (#{integration.metadata["username"]})"
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
    author_raw: [:author, :raw],
    author_login: [:author, :user, :nickname],
    author_url: [:author, :links, :html, :href],
    timestamp: :date,
    parents: {
      parents: {
        url: [:links, :html, :href],
        sha: [:hash]
      }
    }
  }

  def pr_closed?(pr)
    %w[MERGED DECLINED].include?(pr[:state])
  end

  def pr_open?(pr)
    pr[:state] == "OPEN"
  end

  def repos(workspace)
    with_api_retries { installation.list_repos(workspace, REPOS_TRANSFORMATIONS) }
  end

  def find_or_create_webhook!(id:, train_id:)
    GitHub::Result.new do
      if id
        webhook = with_api_retries { installation.find_webhook(code_repository_name, id, WEBHOOK_TRANSFORMATIONS) }
        if webhook[:url] == events_url(train_id:) && (installation.class::WEBHOOK_EVENTS - webhook[:events]).empty?
          webhook
        else
          with_api_retries { installation.update_repo_webhook!(code_repository_name, webhook[:id], events_url(train_id:), WEBHOOK_TRANSFORMATIONS) }
        end
      else
        with_api_retries { installation.create_repo_webhook!(code_repository_name, events_url(train_id:), WEBHOOK_TRANSFORMATIONS) }
      end
    rescue Installations::Bitbucket::Error => ex
      raise ex unless ex.reason == :webhook_not_found
      with_api_retries { installation.create_repo_webhook!(code_repository_name, events_url(train_id:), WEBHOOK_TRANSFORMATIONS) }
    end
  end

  def create_branch!(from, to, source_type: :branch)
    with_api_retries { installation.create_branch!(code_repository_name, from, to, source_type:) }
  end

  def commit_log(from_branch, to_branch)
    with_api_retries { installation.commits_between(code_repository_name, from_branch, to_branch, COMMITS_TRANSFORMATIONS) }
  end

  def diff_between?(from_branch, to_branch, from_type: :branch)
    with_api_retries { installation.diff?(code_repository_name, from_branch, to_branch, from_type) }
  end

  def branch_head_sha(branch, sha_only: true)
    with_api_retries { installation.head(code_repository_name, branch, sha_only:, commit_transforms: COMMITS_TRANSFORMATIONS) }
  end

  def branch_exists?(branch_name)
    with_api_retries { installation.get_branch(code_repository_name, branch_name) }.present?
  rescue Installations::Error => ex
    raise ex unless ex.reason == :not_found
    false
  end

  def branch_url(branch_name)
    "https://bitbucket.org/#{code_repository_name}/branch/#{branch_name}"
  end

  def tag_url(tag_name)
    "https://bitbucket.org/#{code_repository_name}/src/#{tag_name}"
  end

  def compare_url(to_branch, from_branch)
    "https://bitbucket.org/#{code_repository_name}/branch/#{from_branch}?dest=#{CGI.escapeURIComponent(to_branch)}"
  end

  def pull_requests_url(branch_name, open: false)
    state = open ? "OPEN" : "ALL"
    q = URI.encode_www_form("state" => state, "at" => branch_name)
    "https://bitbucket.org/#{code_repository_name}/pull-requests/?#{q}"
  end

  def tag_exists?(tag_name)
    with_api_retries { installation.get_tag(code_repository_name, tag_name) }.present?
  rescue Installations::Error => ex
    raise ex unless ex.reason == :not_found
    false
  end

  def create_release!(tag_name, branch_name, _) = create_tag!(tag_name, branch_name)

  def create_tag!(tag_name, sha)
    with_api_retries { installation.create_tag!(code_repository_name, tag_name, sha) }
  end

  def create_pr!(to_branch_ref, from_branch_ref, title, description)
    with_api_retries do
      installation
        .create_pr!(code_repository_name, to_branch_ref, from_branch_ref, title, description, PR_TRANSFORMATIONS)
        .merge_if_present(source: :bitbucket)
    end
  end

  def find_pr(to_branch_ref, from_branch_ref)
    with_api_retries do
      installation
        .find_pr(code_repository_name, to_branch_ref, from_branch_ref, PR_TRANSFORMATIONS)
        .merge_if_present(source: :bitbucket)
    end
  end

  def get_pr(pr_number)
    with_api_retries { installation.get_pr(code_repository_name, pr_number, PR_TRANSFORMATIONS).merge_if_present(source: :bitbucket) }
  end

  def merge_pr!(pr_number)
    with_api_retries { installation.merge_pr!(code_repository_name, pr_number) }
  end

  def create_patch_pr!(to_branch, patch_branch, commit_hash, pr_title, pr_description)
    with_api_retries do
      installation
        .patch_pr(code_repository_name, to_branch, patch_branch, commit_hash, pr_title, pr_description, PR_TRANSFORMATIONS)
        .merge_if_present(source: :bitbucket)
    end
  end

  def enable_auto_merge!(_pr_number)
    true
  end

  # CI/CD

  WORKFLOW_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  WORKFLOW_RUN_TRANSFORMATIONS = {
    ci_ref: :uuid,
    number: :build_number
  }

  ARTIFACTS_TRANSFORMATIONS = {
    id: :name,
    name: :name,
    size_in_bytes: :size,
    archive_download_url: [:links, :self, :href],
    generated_at: :created_on
  }

  def workflows(branch_name)
    cache.fetch(workflows_cache_key(branch_name), expires_in: 120.minutes) do
      with_api_retries { installation.list_pipeline_selectors(code_repository_name, branch_name) }
    end
  rescue Installations::Error
    []
  end

  def workflow_retriable? = false

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil, _deploy_action_enabled = false)
    with_api_retries do
      res = installation.trigger_pipeline!(code_repository_name, ci_cd_channel, branch_name, inputs, commit_hash, WORKFLOW_RUN_TRANSFORMATIONS)
      res.merge(ci_link: "https://bitbucket.org/#{code_repository_name}/pipelines/results/#{res[:number]}")
    end
  end

  def retry_workflow_run!(_ci_ref)
    raise Integrations::UnsupportedAction
  end

  def cancel_workflow_run!(ci_ref)
    with_api_retries { installation.cancel_pipeline!(code_repository_name, ci_ref) }
  end

  def find_workflow_run(_workflow_id, _branch, _commit_sha)
    raise Integrations::UnsupportedAction
  end

  def get_workflow_run(pipeline_id)
    with_api_retries { installation.get_pipeline(code_repository_name, pipeline_id) }
  end

  def get_artifact_v2(_, _, external_workflow_run_id:)
    raise Installations::Error.new("Could not find the artifact", reason: :artifact_not_found) if external_workflow_run_id.blank?

    # bitbucket expects uuids surrounded by curly braces, like {uuid} in all api requests
    # except for the file name, where it doesn't for some reason
    artifact_name = "build-#{external_workflow_run_id}".gsub(/{/, "").gsub(/}/, "")

    artifact = with_api_retries { installation.get_file(code_repository_name, artifact_name, ARTIFACTS_TRANSFORMATIONS) }
    raise Installations::Error.new("Could not find the artifact", reason: :artifact_not_found) if artifact.blank?

    Rails.logger.debug { "Downloading artifact #{artifact}" }
    artifact_file = with_api_retries { installation.download_artifact(artifact[:archive_download_url]) }
    raise Installations::Error.new("Could not find the artifact", reason: :artifact_not_found) if artifact_file.blank?

    {artifact:, stream: Artifacts::Stream.new(artifact_file)}
  end

  def artifact_url
    raise Integrations::UnsupportedAction
  end

  def get_artifact(_, _)
    raise Integrations::UnsupportedAction
  end

  private

  MAX_RETRY_ATTEMPTS = 2
  RETRYABLE_ERRORS = []

  def with_api_retries(attempt: 0, &)
    yield
  rescue Installations::Error => ex
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
    set_tokens(Installations::Bitbucket::Api.oauth_refresh_token(oauth_refresh_token, redirect_uri))
    save!
  end

  def set_tokens(tokens)
    assign_attributes(oauth_access_token: tokens.access_token, oauth_refresh_token: tokens.refresh_token) if tokens
  end

  def app_config
    app.config
  end

  def redirect_uri
    bitbucket_callback_url(link_params)
  end

  def events_url(params)
    bitbucket_events_url(**tunneled_link_params, **params)
  end

  def workflows_cache_key(branch_name)
    "app/#{app.id}/bitbucket_integration/#{id}/workflows/#{branch_name}"
  end
end
