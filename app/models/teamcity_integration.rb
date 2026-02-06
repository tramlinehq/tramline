# == Schema Information
#
# Table name: teamcity_integrations
#
#  id                      :uuid             not null, primary key
#  access_token            :string
#  cf_access_client_secret :string
#  project_config          :jsonb
#  server_url              :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  cf_access_client_id     :string
#
class TeamcityIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/teamcity_small.png".freeze

  API = Installations::Teamcity::Api

  # Response transformation mappings
  BUILD_CONFIGS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  BUILD_RUN_TRANSFORMATIONS = {
    ci_ref: :id,
    ci_link: :webUrl,
    number: :number,
    unique_number: :number
  }

  PROJECTS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    description: :description
  }

  ARTIFACTS_TRANSFORMATIONS = {
    id: :name,
    name: :name,
    size_in_bytes: :size,
    archive_download_url: :href
  }

  validate :correct_key, on: :create
  validate :cloudflare_credentials_both_or_neither
  validates :server_url, presence: true
  validates :access_token, presence: true

  encrypts :access_token, deterministic: true
  encrypts :cf_access_client_id, deterministic: true
  encrypts :cf_access_client_secret, deterministic: true

  delegate :integrable, to: :integration
  delegate :cache, to: Rails

  def project_id
    project_config&.fetch("id", nil)
  end

  def cloudflare_credentials
    return nil unless cf_access_client_id.present? && cf_access_client_secret.present?
    {
      client_id: cf_access_client_id,
      client_secret: cf_access_client_secret
    }
  end

  def installation
    API.new(server_url, access_token, cloudflare_credentials: cloudflare_credentials)
  end

  def to_s
    "teamcity"
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

  def further_setup?
    true
  end

  def setup
    list_projects
  end

  def connection_data
    return unless integration.metadata
    "Server: #{server_url}"
  end

  def list_projects
    installation.list_projects(PROJECTS_TRANSFORMATIONS)
  end

  def metadata
    { server_url: server_url, version: installation.server_version }
  end

  def workflows(_ = nil, bust_cache: false)
    return [] unless project_id

    Rails.cache.delete(workflows_cache_key) if bust_cache
    cache.fetch(workflows_cache_key, expires_in: 120.minutes) do
      installation.list_build_configurations(project_id, BUILD_CONFIGS_TRANSFORMATIONS)
    end
  end

  def trigger_workflow_run!(build_type_id, branch_name, inputs, commit_hash = nil)
    installation.trigger_build(
      build_type_id,
      branch_name,
      inputs,
      commit_hash,
      BUILD_RUN_TRANSFORMATIONS
    )
  end

  def cancel_workflow_run!(build_id)
    installation.cancel_build(build_id)
  end

  def get_workflow_run(build_id)
    installation.get_build(build_id)
  end

  def find_workflow_run(build_type_id, branch, commit_sha)
    installation.find_build(build_type_id, branch, commit_sha, BUILD_RUN_TRANSFORMATIONS)
  end

  def artifact_url(build_id, artifact_name_pattern)
    installation
      .list_artifacts(build_id)
      .then { |artifacts| API.filter_by_name(artifacts, artifact_name_pattern) }
      .then { |artifacts| API.find_biggest(artifacts) }
      .then { |artifact| artifact&.dig(:href) }
  end

  def get_artifact(artifact_path, artifact_name_pattern, external_workflow_run_id: nil)
    raise Installations::Error.new("Could not find the artifact", reason: :artifact_not_found) if artifact_path.blank?

    build_id = external_workflow_run_id
    artifact = installation.get_artifact_metadata(build_id, artifact_path, ARTIFACTS_TRANSFORMATIONS)
    raise Installations::Error.new("Could not find the artifact", reason: :artifact_not_found) if artifact.blank?

    stream = installation.download_artifact(build_id, artifact_path)
    {artifact:, stream: Artifacts::Stream.new(stream)}
  end

  def public_icon_img
    PUBLIC_ICON
  end

  def workflow_retriable? = false

  def workflow_retriable_in_place? = false

  private

  def correct_key
    return unless server_url.present? && access_token.present?

    installation.server_version
  rescue Installations::Error, HTTP::Error, JSON::ParserError
    errors.add(:access_token, :invalid_credentials)
  end

  def cloudflare_credentials_both_or_neither
    has_id = cf_access_client_id.present?
    has_secret = cf_access_client_secret.present?

    if has_id != has_secret
      errors.add(:base, "Both Cloudflare Client ID and Secret must be provided together")
    end
  end

  def workflows_cache_key
    "app/#{integrable.id}/teamcity_integration/#{id}/workflows"
  end
end
