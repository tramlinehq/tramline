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
  include Loggable

  validate :correct_key, on: :create

  delegate :crashlytics_project, to: :config

  API = Installations::Crashlytics::Api

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

  def firebase_installation
    Installations::Google::Firebase::Api.new(project_number, access_key)
  end

  def to_s
    "crashlytics"
  end

  def find_release(platform, version, build_number)
    return nil if version.blank?
    installation.find_release(crashlytics_project(platform), version, build_number, RELEASE_TRANSFORMATIONS, integrable.bundle_identifier)
  end

  private

  def bq_access?
    data = installation.get_bq_data
    data.present?
  rescue Installations::Crashlytics::Error => ex
    elog(ex.reason)
    nil
  end

  def correct_key
    errors.add(:json_key, :invalid_config) if firebase_installation.list_apps(APPS_TRANSFORMATIONS).blank?
    errors.add(:json_key, :no_bq_datasets) unless bq_access?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::Firebase::Error => ex
    errors.add(:json_key, ex.reason)
  end

  def list_apps_cache_key
    "google_firebase_integration/#{id}/list_apps"
  end
end
