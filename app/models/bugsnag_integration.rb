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
    slug: :slug
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

  def find_release(version, build_number)
    installation.find_release(project, version, build_number)
  end

  private

  def app_config
    integration.app.config
  end

  def correct_key
    if access_token.present?
      errors.add(:access_token, :no_orgs) if list_organizations.size < 1
    end
  end
end
