class BitriseIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Providable
  include Rails.application.routes.url_helpers

  delegate :project_id, to: :app_config

  encrypts :access_token, deterministic: true

  def installation
    Installations::Bitrise::Api.new(access_token)
  end

  def to_s
    "bitrise"
  end

  def creatable?
    true
  end

  def connectable?
    false
  end

  # FIXME: what is this really?
  def belongs_to_project?
    true
  end

  # Special function if acts as project
  def list_apps
    installation.list_apps
  end

  # CI/CD

  def workflows
    return [] unless integration.ci_cd?
    installation
      .list_workflows(project_id)
      .map { |workflow| {id: workflow, name: workflow} }
  end

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil)
    installation.run_workflow!(project_id, ci_cd_channel, branch_name, inputs, commit_hash)
  end

  def find_workflow_run(_workflow_id, _branch, _commit_sha)
    raise Integrations::UnsupportedAction
  end

  def get_workflow_run(workflow_run_id)
    Sidekiq.logger.info "bitrise -- getting workflow run for #{workflow_run_id}"
    installation.get_workflow_run(project_id, workflow_run_id)
  end

  # NOTE: this is bitrise specific right now
  def artifact_url(workflow_run_id)
    installation.artifact_url(project_id, workflow_run_id)
  end

  def download_stream(artifact_url)
    installation.artifact_io_stream(artifact_url)
  end

  private

  def app_config
    integration.app.config
  end
end
