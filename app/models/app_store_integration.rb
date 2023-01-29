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

  validate :correct_key, on: :create

  attr_accessor :p8_key_file

  CHANNELS_TRANSFORMATIONS = {
    id: :id,
    name: :name
  }

  BUILD_TRANSFORMATIONS = {
    name: :version_string,
    build_number: :build_number,
    status: :beta_external_state,
    added_at: :uploaded_date
  }

  raise InvalidBuildTransformations if Set.new(BUILD_TRANSFORMATIONS.keys) != Set.new(ExternalBuild.minimum_required)

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

  delegate :find_app, to: :installation

  def promote_to_testflight(beta_group_id, build_number)
    installation.add_build_to_group(beta_group_id, build_number)
  end

  def build_channels
    installation.external_groups(CHANNELS_TRANSFORMATIONS).map { |channel| channel.slice(:id, :name) }
  end

  def to_s
    "app_store"
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
    errors.add(:key_id, :no_app_found) if find_app.blank?
  end
end
