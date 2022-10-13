class GithubIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Providable
  include Rails.application.routes.url_helpers

  delegate :code_repository_name, to: :app_config

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://github.com/apps/{app_name}/installations/new{?params*}")

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
    installation.list_repos
  end

  def create_webhook!(url_params)
    installation.create_repo_webhook!(code_repository_name, events_url(url_params))
  end

  def create_tag!(tag_name, branch)
    installation.create_tag!(code_repository_name, tag_name, branch)
  end

  def create_branch!(from, to)
    installation.create_branch!(code_repository_name, from, to)
  end

  def branch_url(repo, branch_name)
    "https://github.com/#{repo}/tree/#{branch_name}"
  end

  def tag_url(repo, tag_name)
    "https://github.com/#{repo}/releases/tag/#{tag_name}"
  end

  def installation
    Installations::Github::Api.new(installation_id)
  end

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

  # FIXME: what is this really?
  def belongs_to_project?
    false
  end

  ## CI/CD

  def workflows
    return [] unless integration.ci_cd?
    installation.list_workflows(code_repository_name)
  end

  def trigger_workflow_run!(ci_cd_channel, ref, inputs, _commit_hash = nil)
    raise WorkflowRun unless installation.run_workflow!(code_repository_name, ci_cd_channel, ref, inputs)
  end

  def find_workflow_run(workflow_id, branch, commit_sha)
    installation.find_workflow_run(code_repository_name, workflow_id, branch, commit_sha)
  end

  def get_workflow_run(workflow_run_id)
    installation.get_workflow_run(code_repository_name, workflow_run_id)
  end

  def artifact_url
    raise Integrations::UnsupportedAction
  end

  def download_stream(artifacts_url)
    installation
      .artifacts(artifacts_url)
      .reject { |artifact| artifact["name"] == "version" }
      .first["archive_download_url"]
      .then { |url| installation.artifact_io_stream(url) }
  end

  def unzip_artifact?
    true
  end

  private

  def app_config
    integration.app.config
  end

  def events_url(params)
    if Rails.env.development?
      github_events_url(host: ENV["WEBHOOK_HOST_NAME"], **params)
    else
      github_events_url(host: ENV["HOST_NAME"], protocol: "https", **params)
    end
  end
end
