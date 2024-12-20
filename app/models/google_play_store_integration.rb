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

  delegate :integrable, to: :integration, allow_nil: true
  delegate :refresh_external_app, :bundle_identifier, to: :integrable, allow_nil: true

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  after_create :draft_check
  after_create_commit :refresh_external_app

  PROD_CHANNEL = {id: :production, name: "Production", is_production: true}.freeze
  BETA_CHANNEL = {id: :beta, name: "Open testing", is_production: false}.freeze
  CHANNELS = [
    PROD_CHANNEL,
    BETA_CHANNEL,
    {id: :alpha, name: "Closed testing - Alpha", is_production: false},
    {id: :internal, name: "Internal testing", is_production: false}
  ]
  PUBLIC_CHANNELS = %w[production beta alpha]
  IN_PROGRESS_STORE_STATUS = %w[inProgress].freeze
  ACTIVE_STORE_STATUSES = %w[completed inProgress].freeze

  DEVELOPER_URL_TEMPLATE =
    Addressable::Template.new("https://play.google.com/console/u/0/developers/{project_id}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/play-console.png".freeze
  MAX_RETRY_ATTEMPTS = 3
  ALLOWED_ERRORS = [:build_exists_in_build_channel]
  RETRYABLE_ERRORS = [:timeout, :duplicate_call, :unauthorized]

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::PlayDeveloper::Api.new(bundle_identifier, access_key)
  end

  def create_draft_release(channel, build_number, version, release_notes, retry_on_review_fail: false)
    execute_with_retry(retry_on_review_fail:) do |skip_review|
      installation.create_draft_release(channel, build_number, version, release_notes, skip_review:)
    end
  end

  def rollout_release(channel, build_number, version, rollout_percentage, release_notes, retry_on_review_fail: false)
    execute_with_retry(retry_on_review_fail:) do |skip_review|
      installation.create_release(channel, build_number, version, rollout_percentage, release_notes, skip_review:)
    end
  end

  def halt_release(channel, build_number, version, rollout_percentage, retry_on_review_fail: true)
    execute_with_retry(retry_on_review_fail:) do |skip_review|
      installation.halt_release(channel, build_number, version, rollout_percentage, skip_review:)
    end
  end

  def upload(file)
    execute_with_retry(retry_on_review_fail: true) do |skip_review|
      installation.upload(file, skip_review:)
    rescue Installations::Google::PlayDeveloper::Error => ex
      raise ex unless ALLOWED_ERRORS.include?(ex.reason)
    end
  end

  def metadata
    {}
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
    integrable&.set_draft_status!
  end

  def draft_check?
    channel_data.find { |c| PUBLIC_CHANNELS.include?(c[:name]) && c[:releases].present? }.blank?
  end

  def build_present_in_public_track?(build_number)
    channel_data&.any? { |c| PUBLIC_CHANNELS.include?(c[:name]) && build_number.in?(c[:releases].pluck(:build_number)) }
  end

  def build_present_in_channel?(channel, build_number)
    track_data = installation.get_track(channel, CHANNEL_DATA_TRANSFORMATIONS)
    return unless track_data
    track_data[:releases].any? { |r| r[:build_number].eql?(build_number.to_s) && ACTIVE_STORE_STATUSES.include?(r[:status]) }
  end

  def to_s
    "google_play_store"
  end

  def connection_data
    "Bundle Identifier: #{bundle_identifier}"
  end

  def channels
    default_channels = CHANNELS.map(&:with_indifferent_access)
    channel_data.each do |chan|
      next if default_channels.pluck(:id).map(&:to_s).include?(chan[:name])
      default_channels << {id: chan[:name], name: "Closed testing - #{chan[:name]}", is_production: false}.with_indifferent_access
    end
    default_channels
  end

  def pick_default_beta_channel
    BETA_CHANNEL
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
        localizations: {release_notes: {language: :language, text: :text}},
        version_string: :name,
        status: :status,
        user_fraction: :user_fraction,
        build_number: [:version_codes, 0]
      }
    }
  }

  APP_TRANSFORMS = {
    default_locale: :default_language,
    contact_website: :contact_website,
    contact_email: :contact_email,
    contact_phone: :contact_phone
  }

  def find_app
    @find_app ||= installation.app_details(APP_TRANSFORMS)
  rescue Installations::Google::PlayDeveloper::Error => ex
    elog(ex)
  end

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

  delegate :find_build, to: :installation

  def deep_link(_, _)
    nil
  end

  def find_build_in_track(channel, build_number)
    installation.get_track(channel, CHANNEL_DATA_TRANSFORMATIONS).dig(:releases)&.find { |r| r[:build_number] == build_number.to_s }
  end

  def build_in_progress?(channel, build_number)
    response = find_build_in_track(channel, build_number)
    response.present? && GooglePlayStoreIntegration::IN_PROGRESS_STORE_STATUS.include?(response[:status])
  end

  private

  def execute_with_retry(attempt: 0, skip_review: false, retry_on_review_fail: false, &block)
    GitHub::Result.new do
      yield(skip_review)
    rescue Installations::Google::PlayDeveloper::Error => ex
      raise ex if attempt >= MAX_RETRY_ATTEMPTS
      next_attempt = attempt + 1

      if ex.reason == :app_review_rejected && retry_on_review_fail
        return execute_with_retry(attempt: next_attempt, skip_review: true, retry_on_review_fail:, &block)
      end

      if RETRYABLE_ERRORS.include?(ex.reason)
        return execute_with_retry(attempt: next_attempt, retry_on_review_fail:, &block)
      end

      raise ex
    end
  end

  def project_id
    JSON.parse(json_key)["project_id"]&.split("-")&.third
  end
end
