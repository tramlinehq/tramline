# == Schema Information
#
# Table name: bitrise_integrations
#
#  id           :uuid             not null, primary key
#  access_token :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class BitriseIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  API = Installations::Bitrise::Api

  WORKFLOWS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  APPS_TRANSFORMATIONS = {
    id: :slug,
    name: :title,
    provider: :provider,
    repo_url: :repo_url,
    avatar_url: :avatar_url
  }

  WORKFLOW_RUN_TRANSFORMATIONS = {
    ci_ref: :build_slug,
    ci_link: :build_url
  }

  ORGANIZATIONS_TRANSFORMATIONS = {
    icon_url: :avatar_icon_url,
    name: :name,
    id: :slug
  }

  delegate :project, to: :app_config

  validate :correct_key, on: :create
  validates :access_token, presence: true

  encrypts :access_token, deterministic: true

  def installation
    API.new(access_token)
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

  def store?
    false
  end

  # FIXME: what is this really?
  def belongs_to_project?
    true
  end

  def connection_data
    return unless integration.metadata
    "Teams: " + integration.metadata.map { |m| "#{m["name"]} (#{m["id"]})" }.join(", ")
  end

  # Special function if acts as project
  def list_apps
    installation.list_apps(APPS_TRANSFORMATIONS)
  end

  def metadata
    installation.list_organizations(ORGANIZATIONS_TRANSFORMATIONS)
  end

  # CI/CD

  def workflows
    return [] unless integration.ci_cd?
    installation.list_workflows(project, WORKFLOWS_TRANSFORMATIONS)
  end

  def trigger_workflow_run!(ci_cd_channel, branch_name, inputs, commit_hash = nil)
    installation.run_workflow!(project, ci_cd_channel, branch_name, inputs, commit_hash, WORKFLOW_RUN_TRANSFORMATIONS)
  end

  def find_workflow_run(_workflow_id, _branch, _commit_sha)
    raise Integrations::UnsupportedAction
  end

  def get_workflow_run(workflow_run_id)
    installation.get_workflow_run(project, workflow_run_id)
  end

  # NOTE: this is bitrise specific right now
  def artifact_url(workflow_run_id)
    installation
      .artifacts(project, workflow_run_id)
      .then { |artifacts| API.filter_android(artifacts) }
      .then { |artifacts| API.find_biggest(artifacts) }
      .then { |chosen_package| API.artifact_url(project, workflow_run_id, chosen_package) }
  end

  def get_artifact(artifact_url)
    raise Integration::NoBuildArtifactAvailable if artifact_url.blank?
    Artifacts::Stream.new(installation.artifact_io_stream(artifact_url))
  end

  def unzip_artifact?
    false
  end

  private

  def app_config
    integration.app.config
  end

  def correct_key
    if access_token.present?
      errors.add(:access_token, :no_apps) if list_apps.size < 1
    end
  end
end
