# == Schema Information
#
# Table name: google_firebase_integrations
#
#  id             :uuid             not null, primary key
#  json_key       :string
#  project_number :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  app_id         :string
#
class GoogleFirebaseIntegration < ApplicationRecord
  has_paper_trail
  encrypts :json_key, deterministic: true

  include Providable
  include Displayable
  include Loggable

  delegate :cache, to: Rails
  delegate :app, to: :integration

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::Firebase::Api.new(project_number, app_id, access_key)
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

  EMPTY_CHANNEL = {id: :no_testers, name: "No testers (upload only)"}

  def channels
    installation.list_groups(GROUPS_TRANSFORMATIONS)
  end

  def build_channels_cache_key
    "app/#{app.id}/google_firebase_integration/#{id}/build_channels"
  end

  def build_channels(with_production:)
    sliced = cache.fetch(build_channels_cache_key, expires_in: 30.minutes) do
      channels&.map { |channel| channel.slice(:id, :name) }
    end

    (sliced || []).push(EMPTY_CHANNEL)
  end

  def upload(file)
    GitHub::Result.new do
      installation.upload(file)
    end
  end

  def get_upload_status(op_name)
    GitHub::Result.new do
      ReleaseInfo.new(installation.get_upload_status(op_name))
    end
  end

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
    "https://storage.googleapis.com/tramline-public-assets/firebase_small.png".freeze
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

  def group_name(group)
    group.split("/").last
  end

  def releases_present?
    installation.list_releases
  end

  def correct_key
    releases_present?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::Firebase::Error => ex
    errors.add(:json_key, ex.reason)
  end
end
