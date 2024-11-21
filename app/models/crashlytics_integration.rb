# == Schema Information
#
# Table name: crashlytics_integrations
#
#  id             :uuid             not null, primary key
#  json_key       :string
#  project_number :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class CrashlyticsIntegration < ApplicationRecord
  has_paper_trail

  include Providable
  include Displayable
  include Firebasable

  delegate :integrable, to: :integration
  delegate :crashlytics_project, to: :app_config
  alias_method :project, :crashlytics_project

  API = Installations::Crashlytics::Api

  APPS_TRANSFORMATIONS = {
    app_id: :app_id,
    display_name: :display_name,
    platform: :platform
  }

  RELEASE_TRANSFORMATIONS = {
    new_errors_count: :new_errors_count,
    errors_count: :errors_count,
    sessions_in_last_day: :sessions_in_last_day,
    sessions: :sessions,
    sessions_with_errors: :sessions_with_errors,
    daily_users_with_errors: :daily_users_with_errors,
    daily_users: :daily_users,
    total_sessions_in_last_day: :total_sessions_in_last_day,
    external_release_id: :external_release_id
  }

  def installation
    API.new(project_number, access_key)
  end

  def to_s
    "crashlytics"
  end

  def find_release(platform, version, build_number)
    return nil if version.blank?
    installation.find_release(project(platform), version, build_number, RELEASE_TRANSFORMATIONS, integrable.bundle_identifier)
  end

  private

  def app_config
    (integration.integrable_type == "App") ? integration.integrable.config : integration.integrable.app_config
  end

  def bq_access?
    data = installation.get_bq_data
    data.present?
  end

  def correct_key
    if installation.list_apps(APPS_TRANSFORMATIONS).blank? && !bq_access?
      errors.add(:json_key, :invalid_config)
    end
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::Firebase::Error => ex
    errors.add(:json_key, ex.reason)
  end

  def list_apps_cache_key
    "google_firebase_integration/#{id}/list_apps"
  end
end
