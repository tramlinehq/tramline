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

  delegate :app, to: :integration, allow_nil: true
  delegate :refresh_external_app, to: :app

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  after_create :draft_check
  after_create_commit :refresh_external_app

  CHANNELS = [
    {id: :production, name: "production", is_production: true},
    {id: :beta, name: "open testing", is_production: false},
    {id: :alpha, name: "closed testing", is_production: false},
    {id: :internal, name: "internal testing", is_production: false}
  ]

  DEVELOPER_URL_TEMPLATE =
    Addressable::Template.new("https://play.google.com/console/u/0/developers/{project_id}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/play-console.png".freeze
  MAX_RETRY_ATTEMPTS = 3
  ALLOWED_ERRORS = [:build_exists_in_build_channel]
  RETRYABLE_ERRORS = [:timeout, :duplicate_call, :unauthorized, :app_review_rejected]

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier, access_key)
  end

  def rollout_release(channel, build_number, version, rollout_percentage, release_notes)
    GitHub::Result.new do
      installation.create_release(channel, build_number, version, rollout_percentage, release_notes)
    end
  end

  def create_draft_release(channel, build_number, version, release_notes)
    GitHub::Result.new do
      installation.create_draft_release(channel, build_number, version, release_notes)
    end
  end

  def halt_release(channel, build_number, version, rollout_percentage)
    execute_with_retry do |skip_review|
      installation.halt_release(channel, build_number, version, rollout_percentage, skip_review:)
    end
  end

  def upload(file)
    execute_with_retry do |skip_review|
      installation.upload(file, skip_review:)
    rescue Installations::Google::PlayDeveloper::Error => ex
      raise ex unless ALLOWED_ERRORS.include?(ex.reason)
    end
  end

  def metadata
    {}
  end

  def find_build(_)
    raise Integration::UnsupportedAction
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
    true
  end

  def further_setup?
    false
  end

  def draft_check
    app&.set_draft_status!
  end

  def draft_check?
    channel_data.find { |c| c[:name].in?(%w[alpha beta production]) && c[:releases].present? }.blank?
  end

  def build_present_in_public_track?(build_number)
    channel_data&.any? { |c| c[:name].in?(%w[alpha beta production]) && build_number.in?(c[:releases].pluck(:build_number)) }
  end

  def build_present_in_channel?(channel, build_number)
    track_data = installation.get_track(channel, CHANNEL_DATA_TRANSFORMATIONS)
    return unless track_data
    build_number.in?(track_data[:releases].pluck(:build_number))
  end

  def to_s
    "google_play_store"
  end

  def connection_data
    "Bundle Identifier: #{app.bundle_identifier}"
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
  rescue Installations::Google::PlayDeveloper::Error => ex
    elog(ex)
  end

  def build_present_in_tracks?
    channel_data&.pluck(:releases)&.any?(&:present?)
  end

  def correct_key
    errors.add(:json_key, :no_bundles) unless build_present_in_tracks?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::PlayDeveloper::Error => ex
    errors.add(:json_key, ex.reason)
  end

  def project_link
    DEVELOPER_URL_TEMPLATE.expand(project_id:).to_s
  end

  def public_icon_img
    PUBLIC_ICON
  end

  def latest_build_number
    installation.find_latest_build_number
  end

  def deep_link(_, _)
    nil
  end

  private

  def execute_with_retry
    attempt = 1
    skip_review = nil
    GitHub::Result.new do
      yield(skip_review)
    rescue Installations::Google::PlayDeveloper::Error => ex
      attempt += 1
      skip_review = true if ex.reason == :app_review_rejected
      retry if RETRYABLE_ERRORS.include?(ex.reason) && attempt <= MAX_RETRY_ATTEMPTS
      raise ex
    end
  end

  def project_id
    JSON.parse(json_key)["project_id"]&.split("-")&.third
  end
end
