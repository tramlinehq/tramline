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

  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/bugsnag_small.png".freeze

  API = Installations::Bugsnag::Api

  APPS_TRANSFORMATIONS = {
    id: :slug,
    name: :title,
    provider: :provider,
    repo_url: :repo_url,
    avatar_url: :avatar_url
  }

  ORGANIZATIONS_TRANSFORMATIONS = {
    icon_url: :avatar_icon_url,
    name: :name,
    id: :slug
  }

  validate :correct_key, on: :create
  validates :access_token, presence: true

  encrypts :access_token, deterministic: true

  ORGANIZATIONS_TRANSFORMATIONS = {
    name: :name,
    id: :id,
    slug: :slug
  }

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
    list_apps
  end

  def connection_data
    return unless integration.metadata
    "Teams: " + integration.metadata.map { |m| "#{m["name"]} (#{m["id"]})" }.join(", ")
  end

  def list_apps
    installation.list_apps(APPS_TRANSFORMATIONS)
  end

  def list_organizations
    installation.list_organizations(ORGANIZATIONS_TRANSFORMATIONS)
  end

  def metadata
    list_organizations
  end

  def public_icon_img
    PUBLIC_ICON
  end

  private

  def app_config
    integration.app.config
  end

  def correct_key
    if access_token.present?
      errors.add(:access_token, :no_apps) if list_organizations.size < 1
    end
  end
end
