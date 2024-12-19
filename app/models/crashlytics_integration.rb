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
  include Loggable

  encrypts :json_key, deterministic: true

  validate :correct_key, on: :create

  delegate :integrable, to: :integration

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

  def access_key
    StringIO.new(json_key)
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
    false
  end

  def connection_data
    "Project: #{project_number}"
  end

  def to_s
    "crashlytics"
  end

  def metadata
    {}
  end

  def find_release(platform, version, build_number)
    return nil if version.blank?
    installation.find_release(integrable.bundle_identifier, platform, version, build_number, RELEASE_TRANSFORMATIONS)
  end

  # FIXME: This is an incomplete URL. The full URL should contain the project id.
  def dashboard_url(platform:, release_id:)
    "https://console.firebase.google.com".freeze
  end

  private

  def bq_access?
    datasets = installation.datasets
    return false if datasets.blank?
    datasets.key?(:ga4) && datasets.key?(:crashlytics)
  rescue Installations::Crashlytics::Error => ex
    elog(ex.reason)
    nil
  end

  def correct_key
    errors.add(:json_key, :no_bq_datasets) unless bq_access?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::Firebase::Error => ex
    errors.add(:json_key, ex.reason)
  end
end
