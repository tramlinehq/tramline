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
  include Lockable

  delegate :cache, to: Rails
  delegate :integrable, to: :integration, allow_nil: true
  delegate :refresh_external_app, :bundle_identifier, to: :integrable, allow_nil: true

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  after_create_commit :draft_check
  after_create_commit :refresh_external_app

  class LockAcquisitionError < StandardError
    def initialize(msg = "We could not complete this request, as there is another Play Store request in progress. Please retry after a few minutes.")
      super
    end

    def reason = :lock_acquisition_error
  end

  CACHE_EXPIRY = 1.month
  LOCK_NAME_PREFIX = "google_play_store_edit_"
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
  DEVELOPER_URL_TEMPLATE = Addressable::Template.new("https://play.google.com/console/u/0/developers/{project_id}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/play-console.png".freeze
  MAX_RETRY_ATTEMPTS = 3
  ALLOWED_ERRORS = [:build_exists_in_build_channel]
  RETRYABLE_ERRORS = [:timeout, :duplicate_call, :unauthorized]
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

  def access_key
    StringIO.new(json_key)
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

  def to_s
    "google_play_store"
  end

  def connection_data
    "Bundle Identifier: #{bundle_identifier}"
  end

  def pick_default_beta_channel
    BETA_CHANNEL
  end

  def project_link
    DEVELOPER_URL_TEMPLATE.expand(project_id:).to_s
  end

  def public_icon_img
    PUBLIC_ICON
  end

  def deep_link(_, _)
    nil
  end

  def draft_check
    integrable&.set_draft_status!
  end

  def installation
    Installations::Google::PlayDeveloper::Api.new(bundle_identifier, access_key)
  end

  def create_draft_release(channel, build_number, version, release_notes, raise_on_lock_error:, retry_on_review_fail: false)
    execute_with_retry(retry_on_review_fail:, raise_on_lock_error:) do |skip_review|
      installation.create_draft_release(channel, build_number, version, release_notes, skip_review:)
    end
  end

  def rollout_release(channel, build_number, version, rollout_percentage, release_notes, raise_on_lock_error:, retry_on_review_fail: false)
    execute_with_retry(retry_on_review_fail:, raise_on_lock_error:) do |skip_review|
      installation.create_release(channel, build_number, version, rollout_percentage, release_notes, skip_review:)
    end
  end

  def halt_release(channel, build_number, version, rollout_percentage, raise_on_lock_error:, retry_on_review_fail: true)
    execute_with_retry(retry_on_review_fail:, raise_on_lock_error:) do |skip_review|
      installation.halt_release(channel, build_number, version, rollout_percentage, skip_review:)
    end
  end

  def upload(file, raise_on_lock_error:)
    execute_with_retry(retry_on_review_fail: true, raise_on_lock_error:) do |skip_review|
      installation.upload(file, skip_review:)
    rescue Installations::Google::PlayDeveloper::Error => ex
      raise ex unless ALLOWED_ERRORS.include?(ex.reason)
    end
  end

  def build_present_in_channel?(channel, build_number, raise_on_lock_error:)
    result = execute_with_retry(lock_priority: :low, raise_on_lock_error:) do
      installation.get_track(channel, CHANNEL_DATA_TRANSFORMATIONS)
    end

    return unless result.ok?
    track_data = result.value!
    return unless track_data
    track_data[:releases].any? { |r| r[:build_number].eql?(build_number.to_s) && ACTIVE_STORE_STATUSES.include?(r[:status]) }
  end

  def find_build(build_number, raise_on_lock_error:)
    apk = Flipper.enabled?(:apk_on_play_store, integrable)
    result = execute_with_retry(raise_on_lock_error:) { installation.find_build(build_number, apk:) }
    result.ok? ? result.value! : nil
  end

  def find_build_in_track(channel, build_number, raise_on_lock_error:)
    result = execute_with_retry(lock_priority: :low, raise_on_lock_error:) do
      installation.get_track(channel, CHANNEL_DATA_TRANSFORMATIONS)
    end

    if result.ok?
      value = result.value!
      value.dig(:releases)&.find { |r| r[:build_number] == build_number.to_s }
    end
  end

  def build_active?(channel, build_number, raise_on_lock_error:)
    response = find_build_in_track(channel, build_number, raise_on_lock_error:)
    response.present? && GooglePlayStoreIntegration::ACTIVE_STORE_STATUSES.include?(response[:status])
  end

  def find_app
    return @find_app if @find_app
    result = execute_with_retry(lock_priority: :low, raise_on_lock_error: false) { installation.app_details(APP_TRANSFORMS) }
    result.ok? ? @find_app = result.value! : nil
  end

  def channel_data
    return @channel_data if @channel_data
    result = execute_with_retry(lock_priority: :low, raise_on_lock_error: false) { installation.list_tracks(CHANNEL_DATA_TRANSFORMATIONS) }
    result.ok? ? @channel_data = result.value! : nil
  end

  def draft_check?
    channel_data&.find { |c| PUBLIC_CHANNELS.include?(c[:name]) && c[:releases].present? }.blank?
  end

  def build_channels(with_production: false)
    all_channels = cache.fetch(tracks_cache_key, skip_nil: true, expires_in: CACHE_EXPIRY) do
      default_channels = CHANNELS.map(&:with_indifferent_access)

      channel_data&.each do |chan|
        next if default_channels.pluck(:id).map(&:to_s).include?(chan[:name])

        # Skip form factor production tracks unless with_production is true
        if chan[:name].include?(":") && chan[:name].end_with?(":production")
          next unless with_production
        end

        new_chan = build_channel_from_track(chan[:name])
        default_channels << new_chan
      end

      default_channels
    end

    return all_channels if with_production
    all_channels.reject { |channel| channel[:is_production] }
  end

  private

  def build_channel_from_track(track_name)
    if track_name.include?(":")
      form_factor, track_type = track_name.split(":", 2)

      form_factor_name = case form_factor
      when "android_xr"
        "Android XR"
      when "tv"
        "TV"
      when "wear"
        "Wear OS"
      else
        form_factor.humanize
      end

      track_type_name = case track_type
      when "beta"
        "Open Testing"
      when "internal"
        "Internal Testing"
      when "production"
        "Production"
      else
        "Closed Testing - #{track_type}"
      end

      is_production = track_type == "production"

      {
        id: track_name,
        name: "#{form_factor_name} - #{track_type_name}",
        is_production: is_production
      }.with_indifferent_access
    else
      {
        id: track_name,
        name: "Closed testing - #{track_name}",
        is_production: false
      }.with_indifferent_access
    end
  end

  def latest_build_number
    apk = Flipper.enabled?(:apk_on_play_store, integrable)
    result = execute_with_retry(raise_on_lock_error: false) { installation.find_latest_build_number(apk:) }
    result.ok? ? result.value! : nil
  end

  private

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

  def project_id
    JSON.parse(json_key)["project_id"]&.split("-")&.third
  end

  def execute_with_retry(attempt: 0, skip_review: false, retry_on_review_fail: false, lock_priority: :high, raise_on_lock_error: false, &block)
    result = GitHub::Result.new do
      api_lock(priority: lock_priority) { yield(skip_review) }
    rescue Installations::Google::PlayDeveloper::Error, LockAcquisitionError => ex
      elog(ex, level: :warn)
      raise ex if attempt >= MAX_RETRY_ATTEMPTS
      next_attempt = attempt + 1

      if ex.reason == :app_review_rejected && retry_on_review_fail
        return execute_with_retry(attempt: next_attempt, skip_review: true, retry_on_review_fail:, lock_priority:, &block)
      end

      if RETRYABLE_ERRORS.include?(ex.reason)
        return execute_with_retry(attempt: next_attempt, retry_on_review_fail:, lock_priority:, &block)
      end

      raise ex
    end

    if raise_on_lock_error && result.error.is_a?(LockAcquisitionError)
      # if there's a lock acquisition failure, bubble it up
      raise result.error
    else
      # otherwise, return the result object
      result
    end
  end

  def api_lock(priority: :high, &)
    raise ArgumentError, "You must provide a block" unless block_given?
    name = LOCK_NAME_PREFIX + integrable.id.to_s
    with_lock(name, api_lock_params(priority:), exception: LockAcquisitionError.new) { yield }
  end

  def api_lock_params(priority: :high)
    case priority
    when :high
      # roughly match the sidekiq default timeout (which is 25s)
      {retry_count: 40, retry_delay: 500, ttl: 120_000}
    when :low
      # delay for longer, so high priority locks don't get stuck
      {retry_count: 10, retry_delay: 1000, ttl: 60_000}
    else
      raise ArgumentError, "Invalid priority: #{priority}"
    end
  end

  def tracks_cache_key
    "google_play_store_integration/#{id}/tracks"
  end
end
