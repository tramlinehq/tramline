# == Schema Information
#
# Table name: bugsnag_integrations
#
#  id             :uuid             not null, primary key
#  access_token   :string
#  android_config :jsonb
#  ios_config     :jsonb
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class BugsnagIntegration < ApplicationRecord
  has_paper_trail

  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  attr_accessor :ios_release_stage, :android_release_stage, :ios_project_id, :android_project_id

  CACHE_EXPIRY = 1.month
  API = Installations::Bugsnag::Api

  ORGANIZATIONS_TRANSFORMATIONS = {
    name: :name,
    id: :id,
    slug: :slug
  }

  PROJECTS_TRANSFORMATIONS = {
    name: :name,
    id: :id,
    slug: :slug,
    url: :html_url,
    release_stages: :release_stages
  }

  RELEASE_TRANSFORMATIONS = {
    new_errors_count: :errors_introduced_count,
    errors_count: :errors_seen_count,
    sessions_in_last_day: :sessions_count_in_last_24h,
    sessions: :total_sessions_count,
    sessions_with_errors: :unhandled_sessions_count,
    daily_users_with_errors: :accumulative_daily_users_with_unhandled,
    daily_users: :accumulative_daily_users_seen,
    total_sessions_in_last_day: :total_sessions_count_in_last_24h,
    external_release_id: :release_group_id
  }

  validate :correct_key, on: :create
  validates :access_token, presence: true

  after_initialize :set_bugsnag_config, if: :persisted?

  encrypts :access_token, deterministic: true
  delegate :cache, to: Rails
  delegate :integrable, to: :integration

  def installation
    API.new(access_token)
  end

  def to_s
    "bugsnag"
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
      list_organizations.flat_map { |org| installation.list_projects(org[:id], PROJECTS_TRANSFORMATIONS) }
    end
  end

  def list_organizations
    installation.list_organizations(ORGANIZATIONS_TRANSFORMATIONS)
  end

  def metadata
    list_organizations
  end

  def find_release(platform, version, build_number, _start_date = nil)
    installation.find_release(project_id(platform), release_stage(platform), version, build_number, RELEASE_TRANSFORMATIONS)
  end

  def dashboard_url(platform:, release_id:)
    return if project_url(platform).blank?
    return "#{project_url(platform)}/release_groups/#{release_id}" if release_id.present?
    "#{project_url(platform)}/overview?release_stage=#{release_stage(platform)}"
  end

  def project(platform)
    case platform
    when "android" then android_config&.dig("project_id")
    when "ios" then ios_config&.dig("project_id")
    else
      raise ArgumentError, "Invalid platform: #{platform}"
    end
  end

  def release_stage(platform)
    case platform
    when "android" then android_config&.dig("release_stage")
    when "ios" then ios_config&.dig("release_stage")
    else
      raise ArgumentError, "Invalid platform: #{platform}"
    end
  end

  private

  def set_bugsnag_config
    self.ios_release_stage = ios_config&.fetch("release_stage", nil)
    self.ios_project_id = ios_config&.fetch("project_id", nil)
    self.android_release_stage = android_config&.fetch("release_stage", nil)
    self.android_project_id = android_config&.fetch("project_id", nil)
  end

  def project_url(platform)
    project(platform)&.fetch("url", nil)
  end

  def project_id(platform)
    project(platform)&.fetch("id", nil)
  end

  def app_config
    integrable.config
  end

  def correct_key
    if access_token.present? && list_organizations.blank?
      errors.add(:access_token, :no_orgs)
    end
  end

  def list_projects_cache_key
    "app/#{integrable.id}/bugsnag_integration/#{id}/list_projects"
  end
end
