# == Schema Information
#
# Table name: app_store_integrations
#
#  id         :uuid             not null, primary key
#  p8_key     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  issuer_id  :string
#  key_id     :string
#
class AppStoreIntegration < ApplicationRecord
  has_paper_trail

  InvalidBuildTransformations = Class.new(StandardError)

  encrypts :key_id, deterministic: true
  encrypts :p8_key, deterministic: true
  encrypts :issuer_id, deterministic: true

  include Providable
  include Displayable
  include Loggable

  delegate :app, to: :integration
  delegate :cache, to: Rails
  delegate :refresh_external_app, to: :app

  validate :correct_key, on: :create
  before_create :set_external_details_on_app

  attr_accessor :p8_key_file

  after_create_commit :refresh_external_app

  DEFAULT_PHASED_RELEASE_SEQUENCE = [1, 2, 5, 10, 20, 50, 100]

  CHANNELS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  BUILD_TRANSFORMATIONS = {
    external_id: :id,
    name: :version_string,
    build_number: :build_number,
    status: :beta_external_state,
    added_at: :uploaded_date
  }

  APP_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    bundle_id: :bundle_id
  }

  CHANNEL_DATA_TRANSFORMATIONS = {
    name: :name,
    releases: {
      builds: {
        version_string: :version_string,
        status: :status,
        build_number: :build_number,
        id: :id,
        release_date: :release_date
      }
    }
  }

  RELEASE_TRANSFORMATIONS = {
    external_id: :id,
    status: :app_store_state,
    build_number: :build_number,
    name: :version_name,
    added_at: :created_date,
    phased_release_day: [:phased_release, :current_day_number],
    phased_release_status: [:phased_release, :phased_release_state]
  }

  PROD_CHANNEL = {id: :app_store, name: "App Store", is_production: true}

  unless Set.new(BUILD_TRANSFORMATIONS.keys).superset?(Set.new(ExternalRelease.minimum_required))
    raise InvalidBuildTransformations
  end

  def access_key
    OpenSSL::PKey::EC.new(p8_key)
  end

  def installation
    Installations::Apple::AppStoreConnect::Api.new(app.bundle_identifier, key_id, issuer_id, access_key)
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

  def find_build(build_number)
    GitHub::Result.new { build_info(installation.find_build(build_number, BUILD_TRANSFORMATIONS)) }
  end

  def find_release(build_number)
    GitHub::Result.new { release_info(installation.find_release(build_number, RELEASE_TRANSFORMATIONS)) }
  end

  def find_live_release
    GitHub::Result.new { release_info(installation.find_live_release(RELEASE_TRANSFORMATIONS)) }
  end

  def release_to_testflight(beta_group_id, build_number)
    GitHub::Result.new { installation.add_build_to_group(beta_group_id, build_number) }
  end

  def prepare_release(build_number, version, is_phased_release)
    GitHub::Result.new { installation.prepare_release(build_number, version, is_phased_release) }
  end

  def submit_release(build_number)
    GitHub::Result.new { installation.submit_release(build_number) }
  end

  def start_release(build_number)
    GitHub::Result.new { installation.start_release(build_number) }
  end

  def find_app
    @find_app ||= installation.find_app(APP_TRANSFORMATIONS)
  end

  def channel_data
    installation.current_app_status(CHANNEL_DATA_TRANSFORMATIONS)
  end

  def build_channels(with_production:)
    sliced =
      cache.fetch(build_channels_cache_key, expires_in: 1.hour) do
        installation
          .external_groups(CHANNELS_TRANSFORMATIONS)
          .push(PROD_CHANNEL)
          .map { |channel| channel.slice(:id, :name, :is_production) }
      end

    return sliced if with_production
    sliced.reject { |channel| channel[:is_production] }
  end

  def build_channels_cache_key
    "app/#{app.id}/app_store_integration/#{id}/build_channels"
  end

  def to_s
    "app_store"
  end

  def build_info(build_info)
    TestFlightInfo.new(build_info)
  end

  def release_info(build_info)
    AppStoreReleaseInfo.new(build_info)
  end

  def correct_key
    find_app.present?
  rescue Installations::Apple::AppStoreConnect::Error => ex
    errors.add(:key_id, ex.reason)
  end

  def set_external_details_on_app
    app.set_external_details(find_app[:id])
  end

  class TestFlightInfo
    def initialize(build_info)
      raise ArgumentError, "build_info must be a Hash" unless build_info.is_a?(Hash)
      @build_info = build_info
    end

    attr_reader :build_info

    module BuildInternalState
      PROCESSING = "PROCESSING"
      PROCESSING_EXCEPTION = "PROCESSING_EXCEPTION"
      MISSING_EXPORT_COMPLIANCE = "MISSING_EXPORT_COMPLIANCE"
      READY_FOR_BETA_TESTING = "READY_FOR_BETA_TESTING"
      IN_BETA_TESTING = "IN_BETA_TESTING"
      EXPIRED = "EXPIRED"
      IN_EXPORT_COMPLIANCE_REVIEW = "IN_EXPORT_COMPLIANCE_REVIEW"
    end

    module BuildExternalState
      PROCESSING = "PROCESSING"
      PROCESSING_EXCEPTION = "PROCESSING_EXCEPTION"
      MISSING_EXPORT_COMPLIANCE = "MISSING_EXPORT_COMPLIANCE"
      READY_FOR_BETA_TESTING = "READY_FOR_BETA_TESTING"
      IN_BETA_TESTING = "IN_BETA_TESTING"
      EXPIRED = "EXPIRED"
      READY_FOR_BETA_SUBMISSION = "READY_FOR_BETA_SUBMISSION"
      IN_EXPORT_COMPLIANCE_REVIEW = "IN_EXPORT_COMPLIANCE_REVIEW"
      WAITING_FOR_BETA_REVIEW = "WAITING_FOR_BETA_REVIEW"
      IN_BETA_REVIEW = "IN_BETA_REVIEW"
      BETA_REJECTED = "BETA_REJECTED"
      BETA_APPROVED = "BETA_APPROVED"
    end

    def attributes
      build_info
    end

    def found?
      build_info.present?
    end

    def success?
      build_info[:status].in?(
        [
          BuildExternalState::BETA_APPROVED,
          BuildInternalState::IN_BETA_TESTING
        ]
      )
    end

    def failed?
      build_info[:status].in?(
        [
          BuildExternalState::PROCESSING_EXCEPTION,
          BuildExternalState::MISSING_EXPORT_COMPLIANCE,
          BuildExternalState::EXPIRED,
          BuildExternalState::BETA_REJECTED,
          BuildInternalState::PROCESSING_EXCEPTION,
          BuildInternalState::MISSING_EXPORT_COMPLIANCE,
          BuildInternalState::EXPIRED
        ]
      )
    end
  end

  class AppStoreReleaseInfo
    def initialize(release_info)
      raise ArgumentError, "release_info must be a Hash" unless release_info.is_a?(Hash)
      @release_info = release_info
    end

    attr_reader :release_info

    module AppStoreState
      READY_FOR_SALE = "READY_FOR_SALE"
      PROCESSING_FOR_APP_STORE = "PROCESSING_FOR_APP_STORE"
      PENDING_DEVELOPER_RELEASE = "PENDING_DEVELOPER_RELEASE"
      PENDING_APPLE_RELEASE = "PENDING_APPLE_RELEASE"
      IN_REVIEW = "IN_REVIEW"
      WAITING_FOR_REVIEW = "WAITING_FOR_REVIEW"
      DEVELOPER_REJECTED = "DEVELOPER_REJECTED"
      DEVELOPER_REMOVED_FROM_SALE = "DEVELOPER_REMOVED_FROM_SALE"
      REJECTED = "REJECTED"
      PREPARE_FOR_SUBMISSION = "PREPARE_FOR_SUBMISSION"
      METADATA_REJECTED = "METADATA_REJECTED"
      INVALID_BINARY = "INVALID_BINARY"
    end

    def attributes
      release_info.except(:phased_release_day, :phased_release_status)
    end

    def found?
      release_info.present?
    end

    def phased_release_stage
      return DEFAULT_PHASED_RELEASE_SEQUENCE.count.pred if phased_release_complete?
      release_info[:phased_release_day].pred
    end

    def phased_release_complete?
      release_info[:phased_release_status] == "COMPLETE"
    end

    def live?(build_number)
      release_info[:build_number] == build_number && release_info[:status] == AppStoreState::READY_FOR_SALE
    end

    def success?
      release_info[:status].in?(
        [
          AppStoreState::PENDING_DEVELOPER_RELEASE
        ]
      )
    end

    def failed?
      release_info[:status].in?(
        [
          AppStoreState::REJECTED,
          AppStoreState::INVALID_BINARY,
          AppStoreState::DEVELOPER_REJECTED,
          AppStoreState::METADATA_REJECTED
        ]
      )
    end
  end
end
