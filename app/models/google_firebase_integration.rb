# == Schema Information
#
# Table name: google_firebase_integrations
#
#  id             :uuid             not null, primary key
#  json_key       :string
#  project_number :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class GoogleFirebaseIntegration < ApplicationRecord
  has_paper_trail
  encrypts :json_key, deterministic: true

  self.ignored_columns += %w[app_id]

  include Providable
  include Displayable
  include Loggable
  include PlatformAwareness

  delegate :cache, to: Rails
  delegate :app, to: :integration
  delegate :config, to: :app
  delegate :firebase_app, to: :config

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  after_create_commit :fetch_channels

  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/firebase_small.png".freeze
  CACHE_EXPIRY = 1.month

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::Firebase::Api.new(project_number, access_key)
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

  def controllable_rollout?
    false
  end

  def to_s
    "firebase"
  end

  def connection_data
    "Project: #{project_number}"
  end

  GROUPS_TRANSFORMATIONS = {
    id: :name,
    name: :display_name,
    member_count: :tester_count
  }

  APPS_TRANSFORMATIONS = {
    app_id: :app_id,
    display_name: :display_name,
    platform: :platform
  }

  EMPTY_CHANNEL = {id: :no_testers, name: "No testers (upload only)"}

  def fetch_channels
    RefreshFirebaseChannelsJob.perform_later(id)
  end

  def channels
    installation.list_groups(GROUPS_TRANSFORMATIONS)
  end

  def further_setup?
    true
  end

  def setup
    platform_aware_config(list_apps(platform: "ios"), list_apps(platform: "android"))
  end

  def list_apps(platform:)
    raise ArgumentError, "platform must be valid" unless valid_platforms.include?(platform)

    apps = cache.fetch(list_apps_cache_key, expires_in: CACHE_EXPIRY) do
      installation.list_apps(APPS_TRANSFORMATIONS)
    end

    apps
      .select { |app| app[:platform] == platform }
      .map { |app| app.slice(:app_id, :display_name) }
  end

  def populate_channels!
    cache.write(build_channels_cache_key, get_all_channels, expires_in: CACHE_EXPIRY)
  end

  def build_channels(with_production:)
    sliced = cache.fetch(build_channels_cache_key, expires_in: CACHE_EXPIRY) { get_all_channels }
    (sliced || []).push(EMPTY_CHANNEL)
  end

  def upload(file, filename, platform:, variant: nil)
    raise ArgumentError, "platform must be valid" unless valid_platforms.include?(platform)

    GitHub::Result.new do
      installation.upload(file, filename, firebase_app(platform, variant:))
    end
  end

  def get_upload_status(op_name)
    GitHub::Result.new do
      ReleaseInfo.new(installation.get_upload_status(op_name))
    end
  end

  delegate :update_release_notes, to: :installation

  def release(release_name, group)
    GitHub::Result.new do
      installation.send_to_group(release_name, group_name(group))
    end
  end

  def metadata
    {}
  end

  # FIXME: This is an incomplete URL. The full URL should contain the project id.
  def project_link
    "https://console.firebase.google.com/u/0".freeze
  end

  def public_icon_img
    PUBLIC_ICON
  end

  def deep_link(release, platform)
    return if release.blank? || platform.blank?
    "https://appdistribution.firebase.google.com/testerapps/#{firebase_app(platform)}/releases/#{release_name(release)}"
  end

  class ReleaseInfo
    def initialize(release_info)
      raise ArgumentError, "release_info must be a Hash" unless release_info.is_a?(Hash)
      @release_info = release_info
      validate_op
    end

    attr_reader :release_info

    def validate_op
      raise Installations::Google::Firebase::OpError.new(release_info[:error]) if done? && error?
    end

    def release = release_info.dig(:response, :release)

    def name = release&.dig(:displayVersion)

    def id = release&.dig(:name)

    def build_number = release&.dig(:buildVersion)

    def added_at = release&.dig(:createTime)

    def status = release_info&.dig(:response, :result)

    def console_link = release&.dig(:firebaseConsoleUri)

    def done? = release_info[:done]

    def error? = release_info[:error].present?
  end

  private

  def valid_platforms
    App.platforms.slice(:android, :ios).keys
  end

  def get_all_channels
    channels&.map { |channel| channel.slice(:id, :name) }
  end

  def group_name(group)
    group.split("/").last
  end

  def release_name(release)
    release.split("/").last
  end

  def correct_key
    installation.list_apps(APPS_TRANSFORMATIONS).present?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::Firebase::Error => ex
    errors.add(:json_key, ex.reason)
  end

  def list_apps_cache_key
    "app/#{app.id}/google_firebase_integration/#{id}/list_apps"
  end

  def build_channels_cache_key
    "app/#{app.id}/google_firebase_integration/#{id}/build_channels"
  end
end
