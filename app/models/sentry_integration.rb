# == Schema Information
#
# Table name: sentry_integrations
#
#  id             :uuid             not null, primary key
#  access_token   :string
#  android_config :jsonb
#  ios_config     :jsonb
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class SentryIntegration < ApplicationRecord
  has_paper_trail

  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  attr_accessor :ios_environment, :android_environment, :ios_project, :android_project, :organization_slug

  CACHE_EXPIRY = 1.month
  API = Installations::Sentry::Api

  ORGANIZATIONS_TRANSFORMATIONS = {
    name: :name,
    id: :id,
    slug: :slug
  }

  PROJECTS_TRANSFORMATIONS = {
    name: :name,
    id: :id,
    slug: :slug,
    platform: :platform
  }

  RELEASE_TRANSFORMATIONS = {
    new_errors_count: :new_issues_count,
    errors_count: :total_issues_count,
    sessions: :total_sessions_count,
    sessions_with_errors: :errored_sessions_count,
    daily_users_with_errors: :users_with_errors_count,
    daily_users: :total_users_count,
    external_release_id: :version
  }

  validate :correct_key, on: :create
  validates :access_token, presence: true

  after_initialize :set_sentry_config, if: :persisted?

  encrypts :access_token, deterministic: true
  delegate :cache, to: Rails
  delegate :integrable, to: :integration

  def installation
    API.new(access_token)
  end

  def to_s
    "sentry"
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
    "Organization(s): " + integration.metadata.map { |m| "#{m["name"]} (#{m["slug"]})" }.join(", ")
  end

  def list_projects
    cache.fetch(list_projects_cache_key, expires_in: CACHE_EXPIRY) do
      list_organizations.flat_map { |org| installation.list_projects(org[:slug], PROJECTS_TRANSFORMATIONS) }
    end
  end

  def list_organizations
    installation.list_organizations(ORGANIZATIONS_TRANSFORMATIONS)
  end

  def metadata
    list_organizations
  end

  def find_release(platform, version, build_number, _start_date = nil)
    installation.find_release(
      organization_slug_from_config(platform),
      project_slug(platform),
      environment(platform),
      version,
      build_number,
      RELEASE_TRANSFORMATIONS
    )
  end

  def dashboard_url(platform:, release_id:)
    return if project_url(platform).blank?
    org_slug = organization_slug_from_config(platform)
    proj_slug = project_slug(platform)
    return "#{project_url(platform)}/releases/#{release_id}/" if release_id.present?
    "https://sentry.io/organizations/#{org_slug}/projects/#{proj_slug}/"
  end

  def project(platform)
    case platform
    when "android" then android_config&.dig("project")
    when "ios" then ios_config&.dig("project")
    else
      raise ArgumentError, "Invalid platform: #{platform}"
    end
  end

  def environment(platform)
    case platform
    when "android" then android_config&.dig("environment")
    when "ios" then ios_config&.dig("environment")
    else
      raise ArgumentError, "Invalid platform: #{platform}"
    end
  end

  private

  def set_sentry_config
    self.ios_environment = ios_config&.fetch("environment", nil)
    self.ios_project = ios_config&.fetch("project", nil)
    self.android_environment = android_config&.fetch("environment", nil)
    self.android_project = android_config&.fetch("project", nil)
  end

  def project_url(platform)
    proj = project(platform)
    return nil if proj.blank?
    org_slug = organization_slug_from_config(platform)
    proj_slug = proj["slug"]
    "https://sentry.io/organizations/#{org_slug}/projects/#{proj_slug}"
  end

  def project_slug(platform)
    project(platform)&.fetch("slug", nil)
  end

  def organization_slug_from_config(platform)
    case platform
    when "android" then android_config&.dig("organization_slug")
    when "ios" then ios_config&.dig("organization_slug")
    else
      raise ArgumentError, "Invalid platform: #{platform}"
    end
  end

  def correct_key
    if access_token.present? && list_organizations.blank?
      errors.add(:access_token, :no_orgs)
    end
  end

  def list_projects_cache_key
    "app/#{integrable.id}/sentry_integration/#{id}/list_projects"
  end
end
