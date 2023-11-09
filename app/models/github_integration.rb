# == Schema Information
#
# Table name: github_integrations
#
#  id              :uuid             not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  installation_id :string
#
class GithubIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers
  using RefinedHash

  delegate :code_repository_name, :code_repo_namespace, to: :app_config
  delegate :app, to: :integration
  delegate :organization, to: :app

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://github.com/apps/{app_name}/installations/new{?params*}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/github-small.png".freeze

  API = Installations::Github::Api

  REPOS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    namespace: [:owner, :login],
    full_name: :full_name,
    description: :description,
    repo_url: :html_url,
    avatar_url: [:owner, :avatar_url]
  }

  WORKFLOWS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  WORKFLOW_RUN_TRANSFORMATIONS = {
    ci_ref: :id,
    ci_link: :html_url
  }

  INSTALLATION_TRANSFORMATIONS = {
    id: :id,
    account_name: [:account, :login],
    account_id: [:account, :id],
    avatar_url: [:account, :avatar_url]
  }

  COMMITS_TRANSFORMATIONS = {
    url: :html_url,
    commit_hash: :sha,
    message: [:commit, :message],
    author_name: [:commit, :author, :name],
    author_email: [:commit, :author, :email],
    author_login: [:author, :login],
    timestamp: [:commit, :author, :date],
    parents: [:parents]
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

  PR_TRANSFORMATIONS = {
    source_id: :id,
    number: :number,
    title: :title,
    body: :body,
    url: :html_url,
    state: :state,
    head_ref: [:head, :ref],
    base_ref: [:base, :ref],
    opened_at: :created_at,
    closed_at: :closed_at
  }

  def install_path
    unless integration.version_control? || integration.ci_cd?
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end

    BASE_INSTALLATION_URL
      .expand(app_name: creds.integrations.github.app_name, params: {
        state: integration.installation_state
      }).to_s
  end

  def repos
    installation.list_repos(REPOS_TRANSFORMATIONS)
  end

  WEBHOOK_TRANSFORMATIONS = {
    id: :id,
    events: :events,
    url: [:config, :url]
  }

  def find_or_create_webhook!(id:, train_id:)
    GitHub::Result.new do
      if id
        webhook = installation.find_webhook(code_repository_name, id, WEBHOOK_TRANSFORMATIONS)
        if webhook[:url] == events_url(train_id:) && (installation.class::WEBHOOK_EVENTS - webhook[:events]).empty?
          webhook
        else
          update_webhook!(webhook[:id], train_id:)
        end
      else
        create_webhook!(train_id:)
      end
    rescue Installations::Errors::ResourceNotFound
      create_webhook!(train_id:)
    end
  end

  def create_release!(tag_name, branch)
    installation.create_release!(code_repository_name, tag_name, branch)
  end

  def create_tag!(tag_name, sha)
    installation.create_tag!(code_repository_name, tag_name, sha)
  end

  def create_branch!(from, to, source_type: :branch)
    installation.create_branch!(code_repository_name, from, to, source_type:)
  end

  def branch_url(repo, branch_name)
    "https://github.com/#{repo}/tree/#{branch_name}"
  end

  def tag_url(repo, tag_name)
    "https://github.com/#{repo}/releases/tag/#{tag_name}"
  end

  def compare_url(to_branch, from_branch)
    "https://github.com/#{code_repository_name}/compare/#{to_branch}..#{from_branch}"
  end

  def installation
    API.new(installation_id)
  end

  def project_link = nil

  def to_s
    "github"
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

  def namespaced_branch(branch_name)
    [code_repo_namespace, ":", branch_name].join
  end

  def further_setup?
    false
  end

  def connection_data
    return unless integration.metadata
    "Organization: #{integration.metadata["account_name"]} (#{integration.metadata["account_id"]})"
  end

  def metadata
    installation.get_installation(installation_id, INSTALLATION_TRANSFORMATIONS)
  end

  ## CI/CD

  def workflows
    return [] unless integration.ci_cd?
    installation.list_workflows(code_repository_name, WORKFLOWS_TRANSFORMATIONS)
  end

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil)
    raise WorkflowRun unless installation.run_workflow!(code_repository_name, ci_cd_channel, branch_name, inputs, commit_hash, organization.deploy_action_enabled?)
  end

  def cancel_workflow_run!(ci_ref)
    installation.cancel_workflow!(code_repository_name, ci_ref)
  end

  def retry_workflow_run!(ci_ref)
    installation.retry_workflow!(code_repository_name, ci_ref)
  end

  def find_workflow_run(workflow_id, branch, commit_sha)
    installation.find_workflow_run(code_repository_name, workflow_id, branch, commit_sha, WORKFLOW_RUN_TRANSFORMATIONS)
  end

  def get_workflow_run(workflow_run_id)
    installation.get_workflow_run(code_repository_name, workflow_run_id)
  end

  def artifact_url
    raise Integrations::UnsupportedAction
  end

  # we currently only select the largest artifact from github, since we have no information about the file types
  # in the future, this could be smarter and/or a user input
  def get_artifact(artifacts_url, artifact_name_pattern)
    installation
      .artifacts(artifacts_url)
      .then { |artifacts| API.filter_by_name(artifacts, artifact_name_pattern) }
      .then { |artifacts| API.find_biggest(artifacts) }
      .then { |artifact| installation.artifact_io_stream(artifact) }
      .then { |zip_file| Artifacts::Stream.new(zip_file, is_archive: true) }
  end

  def branch_exists?(branch_name)
    installation.branch_exists?(code_repository_name, branch_name)
  rescue Installations::Errors::ResourceNotFound
    false
  end

  def unzip_artifact?
    true
  end

  def create_pr!(to_branch_ref, from_branch_ref, title, description)
    from = namespaced_branch(from_branch_ref)
    installation.create_pr!(code_repository_name, to_branch_ref, from, title, description, PR_TRANSFORMATIONS).merge_if_present(source: :github)
  end

  def create_patch_pr!(to_branch, patch_branch, commit_hash, pr_title_prefix)
    installation.cherry_pick_pr(code_repository_name, to_branch, commit_hash, patch_branch, pr_title_prefix, PR_TRANSFORMATIONS).merge_if_present(source: :github)
  end

  def find_pr(to_branch_ref, from_branch_ref)
    from = namespaced_branch(from_branch_ref)
    installation.find_pr(code_repository_name, to_branch_ref, from, PR_TRANSFORMATIONS).merge_if_present(source: :github)
  end

  def get_pr(pr_number)
    installation.get_pr(code_repository_name, pr_number, PR_TRANSFORMATIONS).merge_if_present(source: :github)
  end

  def merge_pr!(pr_number)
    installation.merge_pr!(code_repository_name, pr_number)
  end

  def commit_log(from_branch, to_branch)
    installation.commits_between(code_repository_name, from_branch, to_branch, COMMITS_TRANSFORMATIONS)
  end

  def public_icon_img
    PUBLIC_ICON
  end

  def workflow_retriable?
    true
  end

  def branch_head_sha(branch, sha_only: true)
    installation.head(code_repository_name, branch, sha_only:, commit_transforms: COMMITS_TRANSFORMATIONS)
  end

  private

  def create_webhook!(url_params)
    installation.create_repo_webhook!(code_repository_name, events_url(url_params), WEBHOOK_TRANSFORMATIONS)
  end

  def update_webhook!(id, url_params)
    installation.update_repo_webhook!(code_repository_name, id, events_url(url_params), WEBHOOK_TRANSFORMATIONS)
  end

  def app_config
    app.config
  end

  def events_url(params)
    if Rails.env.development?
      github_events_url(host: ENV["WEBHOOK_HOST_NAME"], **params)
    else
      github_events_url(host: ENV["HOST_NAME"], protocol: "https", **params)
    end
  end
end
