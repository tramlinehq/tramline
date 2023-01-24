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

  delegate :app, to: :integration

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  CHANNELS = [
    {id: :production, name: "production"},
    {id: :beta, name: "open testing"},
    {id: :alpha, name: "closed testing"},
    {id: :internal, name: "internal testing"}
  ]

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier, access_key)
  end

  def promote(channel, build_number, version, rollout_percentage)
    GitHub::Result.new do
      installation.promote(channel, build_number, version, rollout_percentage)
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
      logger.error(e)
      Sentry.capture_exception(e)
    end
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

  def to_s
    "google_play_store"
  end

  def channels
    CHANNELS.map(&:with_indifferent_access)
  end

  def build_channels
    channels.map { |channel| channel.slice(:id, :name) }
  end

  def correct_key
    errors.add(:json_key, :no_bundles) if installation.list_bundles.keys.size < 1
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Errors::BundleIdentifierNotFound, Installations::Errors::GooglePlayDeveloperAPIPermissionDenied
    errors.add(:json_key, :bundle_id_not_found)
  rescue Installations::Errors::GooglePlayDeveloperAPIDisabled
    errors.add(:json_key, :dev_api_not_enabled)
  end
end
