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

  self.ignored_columns += %w[app_id]

  include Loggable
  include Providable
  include Displayable
  include Firebasable

  delegate :firebase_app, to: :config

  attr_accessor :json_key_file

  after_create_commit :fetch_channels

  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/firebase_small.png".freeze

  def installation
    Installations::Google::Firebase::Api.new(project_number, access_key)
  end

  alias_method :firebase_installation, :installation

  def controllable_rollout?
    false
  end

  def to_s
    "firebase"
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

  CACHE_EXPIRY = 1.month

  def fetch_channels
    RefreshFirebaseChannelsJob.perform_async(id)
  end

  def channels
    installation.list_groups(GROUPS_TRANSFORMATIONS)
  end

  def populate_channels!
    cache.write(build_channels_cache_key, get_all_channels, expires_in: CACHE_EXPIRY)
  end

  def build_channels(with_production: false)
    sliced = cache.fetch(build_channels_cache_key, expires_in: CACHE_EXPIRY) { get_all_channels }
    (sliced || []).push(EMPTY_CHANNEL)
  end

  def pick_default_beta_channel
    build_channels.first
  end

  def upload(file, filename, platform:)
    GitHub::Result.new do
      installation.upload(file, filename, firebase_app(platform))
    end
  end

  def get_upload_status(op_name)
    GitHub::Result.new do
      ReleaseOpInfo.new(installation.get_upload_status(op_name))
    end
  end

  delegate :update_release_notes, to: :installation

  def release(release_name, groups)
    GitHub::Result.new do
      installation.send_to_group(release_name, group_names(groups))
    end
  end

  BUILD_TRANSFORMATIONS = {
    id: :name,
    name: :display_version,
    build_number: :build_version,
    added_at: :create_time,
    console_link: :firebase_console_uri,
    release_notes: :release_notes
  }

  def find_build(build_number, version_name, platform)
    lookback_period = 2.weeks.ago.rfc3339
    filters = ["createTime >= \"#{lookback_period}\""]
    GitHub::Result.new do
      ReleaseInfo.new(installation.find_build(
        firebase_app(platform),
        build_number,
        version_name,
        and_filters: filters
      ),
        BUILD_TRANSFORMATIONS)
    end
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

  class ReleaseOpInfo
    def initialize(op_info)
      raise ArgumentError, "release_info must be a Hash" unless op_info.is_a?(Hash)
      @op_info = op_info
      validate_op
    end

    RELEASE_TRANSFORMATIONS = {
      name: :displayVersion,
      console_link: :firebaseConsoleUri,
      build_number: :buildVersion,
      added_at: :createTime,
      status: :status,
      id: :name
    }

    attr_reader :op_info

    def validate_op
      raise Installations::Google::Firebase::OpError.new(op_info[:error]) if done? && error?
    end

    def release
      ReleaseInfo.new(op_info.dig(:response, :release), RELEASE_TRANSFORMATIONS) if done?
    end

    def status = op_info&.dig(:response, :result)

    def done? = op_info[:done]

    def error? = op_info[:error].present?
  end

  class ReleaseInfo
    def initialize(release, transforms)
      raise ArgumentError, "release must be a Hash" unless release.is_a?(Hash)
      @release = Installations::Response::Keys.transform([release], transforms).first
    end

    attr_reader :release

    def id = release[:id]

    def name = release[:name]

    def build_number = release[:build_number]

    def added_at = release[:added_at]

    def status = release[:status]

    def console_link = release[:console_link]
  end

  private

  def get_all_channels
    channels&.map { |channel| channel.slice(:id, :name) }
  end

  def group_names(groups)
    groups.map { |group| group.split("/").last }
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

  def build_channels_cache_key
    "google_firebase_integration/#{id}/build_channels"
  end
end
