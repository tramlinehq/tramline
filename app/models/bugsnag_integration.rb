# == Schema Information
#
# Table name: bugsnag_integrations
#
#  id           :uuid             not null, primary key
#  access_token :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class BugsnagIntegration < ApplicationRecord
  has_paper_trail

  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

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
    url: :html_url
  }

  RELEASE_TRANSFORMATIONS = {
    new_errors_count: :errors_introduced_count,
    errors_count: :errors_seen_count,
    sessions_in_last_day: :sessions_count_in_last_24h,
    sessions: :total_sessions_count,
    sessions_with_errors: :unhandled_sessions_count,
    daily_users_with_errors: :accumulative_daily_users_with_unhandled,
    daily_users: :accumulative_daily_users_seen,
    total_sessions_in_last_day: :total_sessions_count_in_last_24h
  }

  validate :correct_key, on: :create
  validates :access_token, presence: true

  encrypts :access_token, deterministic: true
  delegate :bugsnag_project, to: :app_config
  alias_method :project, :bugsnag_project

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
    list_organizations.flat_map { |org| installation.list_projects(org[:id], PROJECTS_TRANSFORMATIONS) }
  end

  def list_organizations
    installation.list_organizations(ORGANIZATIONS_TRANSFORMATIONS)
  end

  def metadata
    list_organizations
  end

  def find_release(platform, version, build_number)
    installation.find_release(project, release_stage_hack(platform), version, build_number, RELEASE_TRANSFORMATIONS)
  end

  def dashboard_url(platform)
    return if project_url.blank?
    "#{project_url}/overview?release_stage=#{release_stage_hack(platform)}"
  end

  private

  def project_url
    app_config.bugsnag_project_id&.fetch("url", nil)
  end

  def release_stage_hack(platform)
    case platform
    when "android"
      "prod"
    when "ios"
      "iOS-prod"
    else
      "prod"
    end
  end

  def app_config
    integration.app.config
  end

  def correct_key
    if access_token.present?
      errors.add(:access_token, :no_orgs) if list_organizations.size < 1
    end
  end
end
