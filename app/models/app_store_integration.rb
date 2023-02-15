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

  if Set.new(BUILD_TRANSFORMATIONS.keys) != Set.new(ExternalBuild.minimum_required)
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

  def find_build(build_number)
    build_info(installation.find_build(build_number, BUILD_TRANSFORMATIONS))
  end

  def find_app
    @find_app ||= installation.find_app(APP_TRANSFORMATIONS)
  end

  def release_to_testflight(beta_group_id, build_number)
    installation.add_build_to_group(beta_group_id, build_number)
  end

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

  def channel_data
    installation.current_app_status(CHANNEL_DATA_TRANSFORMATIONS)
  end

  def build_channels
    cache.fetch(build_channels_cache_key, expires_in: 1.hour) do
      installation
        .external_groups(CHANNELS_TRANSFORMATIONS)
        .map { |channel| channel.slice(:id, :name) }
    end
  end

  def build_channels_cache_key
    "app/#{app.id}/app_store_integration/#{id}/build_channels"
  end

  def to_s
    "testflight"
  end

  def build_info(build_info)
    TestFlightInfo.new(build_info)
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

  def correct_key
    find_app.present?
  rescue Installations::Errors::AppNotFoundInStore
    errors.add(:key_id, :no_app_found)
  rescue Apple::AppStoreConnect::Api::UnknownError
    errors.add(:key_id, :unknown_error)
  end

  def set_external_details_on_app
    app.set_external_details(find_app[:id])
  end
end
