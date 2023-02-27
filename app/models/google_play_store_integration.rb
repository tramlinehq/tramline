# == Schema Information
#
# Table name: google_play_store_integrations
#
#  id                :uuid             not null, primary key
#  json_key          :string
#  original_json_key :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class GooglePlayStoreIntegration < ApplicationRecord
  has_paper_trail
  encrypts :json_key, deterministic: true

  include Providable
  include Displayable
  include Loggable

  delegate :app, to: :integration
  delegate :refresh_external_app, to: :app

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  after_create_commit :refresh_external_app

  CHANNELS = [
    {id: :production, name: "production", is_production: true},
    {id: :beta, name: "open testing", is_production: false},
    {id: :alpha, name: "closed testing", is_production: false},
    {id: :internal, name: "internal testing", is_production: false}
  ]

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier, access_key)
  end

  def rollout_release(channel, build_number, version, rollout_percentage)
    GitHub::Result.new do
      installation.create_release(channel, build_number, version, rollout_percentage)
    end
  end

  def create_draft_release(channel, build_number, version)
    GitHub::Result.new do
      installation.create_draft_release(channel, build_number, version)
    end
  end

  def halt_release(channel, build_number, version, rollout_percentage)
    GitHub::Result.new do
      installation.halt_release(channel, build_number, version, rollout_percentage)
    end
  end

  ALLOWED_ERRORS = [
    Installations::Errors::BuildExistsInBuildChannel,
    Installations::Errors::DuplicatedBuildUploadAttempt
  ]

  DISALLOWED_ERRORS_WITH_REASONS = {
    Installations::Errors::BundleIdentifierNotFound => :bundle_identifier_not_found,
    Installations::Errors::GooglePlayDeveloperAPIInvalidPackage => :invalid_package,
    Installations::Errors::GooglePlayDeveloperAPIAPKsAreNotAllowed => :apks_are_not_allowed
  }

  def upload(file)
    GitHub::Result.new do
      installation.upload(file)
    rescue *ALLOWED_ERRORS => e
      elog(e)
    end
  end

  def find_build(_)
    raise Integrations::UnsupportedAction
  end

  def creatable?
    true
  end

  def connectable?
    false
  end

  def store?
    true
  end

  def controllable_rollout?
    false
  end

  def to_s
    "google_play_store"
  end

  def channels
    CHANNELS.map(&:with_indifferent_access)
  end

  def build_channels(with_production: false)
    sliced = channels.map { |chan| chan.slice(:id, :name, :is_production) }
    return sliced if with_production
    sliced.reject { |channel| channel[:is_production] }
  end

  CHANNEL_DATA_TRANSFORMATIONS = {
    name: :track,
    releases: {
      releases: {
        version_string: :name,
        status: :status,
        build_number: [:version_codes, 0],
        user_fraction: :user_fraction
      }
    }
  }

  def channel_data
    @channel_data ||= installation.list_tracks(CHANNEL_DATA_TRANSFORMATIONS)
  end

  def build_present_in_tracks?
    channel_data.pluck(:releases).any?(&:present?)
  end

  def correct_key
    errors.add(:json_key, :no_bundles) unless build_present_in_tracks?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Errors::BundleIdentifierNotFound, Installations::Errors::GooglePlayDeveloperAPIPermissionDenied
    errors.add(:json_key, :bundle_id_not_found)
  rescue Installations::Errors::GooglePlayDeveloperAPIDisabled
    errors.add(:json_key, :dev_api_not_enabled)
  end
end
