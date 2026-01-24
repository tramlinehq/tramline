# == Schema Information
#
# Table name: submission_configs
#
#  id                                  :bigint           not null, primary key
#  auto_promote                        :boolean          default(FALSE)
#  auto_start_rollout_after_submission :boolean          default(FALSE), not null
#  automatic_rollout                   :boolean          default(FALSE)
#  finish_rollout_in_next_release      :boolean          default(FALSE), not null
#  integrable_type                     :string
#  number                              :integer          indexed, indexed => [release_step_config_id]
#  rollout_enabled                     :boolean          default(FALSE)
#  rollout_stages                      :decimal(8, 5)    default([]), is an Array
#  submission_type                     :string
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  integrable_id                       :uuid
#  release_step_config_id              :bigint           indexed, indexed => [number]
#
class Config::Submission < ApplicationRecord
  self.table_name = "submission_configs"
  FULL_ROLLOUT_VALUE = BigDecimal("100")

  belongs_to :release_step_config, class_name: "Config::ReleaseStep"
  positioned on: :release_step_config, column: :number
  has_one :submission_external, class_name: "Config::SubmissionExternal", inverse_of: :submission_config, dependent: :destroy
  delegated_type :integrable, types: INTEGRABLE_TYPES, validate: false

  before_validation :set_default_production_config, if: -> { !read_only? && production? }
  before_validation :set_default_rollout_for_ios, if: -> { !read_only? && new_record? && ios? && rollout_enabled? }

  validates :submission_type, presence: true
  validate :correct_rollout_stages, if: :rollout_enabled?
  validate :production_release_submission
  validate :cascading_rollout_applicability, if: :finish_rollout_in_next_release?

  accepts_nested_attributes_for :submission_external, allow_destroy: true
  attr_accessor :read_only
  attribute :production_form_factor, :string

  delegate :ios?, :android?, :production?, :platform, to: :release_step_config

  def as_json(options = {})
    {
      submission_type: submission_type,
      number: number,
      auto_promote: auto_promote,
      integrable_id: integrable.id,
      integrable_type: integrable.class.name,
      submission_config: submission_external.as_json,
      finish_rollout_in_next_release: finish_rollout_in_next_release,
      rollout_config: {
        enabled: rollout_enabled,
        stages: rollout_stages,
        automatic: automatic_rollout,
        auto_start_after_submission: auto_start_rollout_after_submission
      }
    }
  end

  def read_only? = read_only

  def submission_class
    submission_type.constantize
  end

  def restricted_public_channel?
    return false unless submission_type == "GooglePlayStoreSubmission"
    GooglePlayStoreIntegration::PUBLIC_CHANNELS.include?(submission_external.identifier)
  end

  def next
    subsequent_number
  end

  def app_variant?
    integrable_type == "AppVariant"
  end

  def self.from_json(json, read_only: false)
    submission = new(json.except("id", "release_step_config_id", "rollout_config", "submission_config").merge(read_only:))
    submission.submission_external = Config::SubmissionExternal.from_json(json["submission_config"])
    submission.rollout_stages = json.dig("rollout_config", "stages")
    submission.rollout_enabled = json.dig("rollout_config", "enabled")
    submission.automatic_rollout = json.dig("rollout_config", "automatic")
    submission.auto_start_rollout_after_submission = json.dig("rollout_config", "auto_start_after_submission")
    submission
  end

  def display
    submission_type.classify.constantize.model_name.human
  end

  def submission_info
    "#{display} • #{submission_external.name}"
  end

  def production_release_submission
    if production?
      errors.add(:integrable_type, :variant_not_allowed) if integrable_type == "AppVariant"
    end
  end

  def correct_rollout_stages
    if rollout_stages.size < 1
      errors.add(:rollout_stages, :at_least_one)
    end

    if rollout_stages[0]&.zero?
      errors.add(:rollout_stages, :zero_rollout)
    end

    if rollout_stages.sort != rollout_stages
      errors.add(:rollout_stages, :increasing_order)
    end

    if rollout_stages.any? { |value| value > FULL_ROLLOUT_VALUE }
      errors.add(:rollout_stages, :max_100)
    end
  end

  def cascading_rollout_applicability
    unless android?
      errors.add(:base, "cascading rollouts are only available for android")
    end

    unless rollout_enabled?
      errors.add(:base, "cascading rollouts are only available with staged rollouts")
    end

    unless rollout_stages.last.to_f < 100.0
      errors.add(:base, "if you enable cascading rollouts, ensure your last rollout is less than 100%")
    end
  end

  def set_default_rollout_for_ios
    self.rollout_stages = AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE
  end

  def set_default_production_config
    set_production_defaults if new_record?
    apply_form_factor_to_identifier if android? && production_form_factor_changed?
  end

  # Parses the form factor from the submission_external identifier
  # e.g., "wear:production" -> "wear", "production" -> nil
  def parsed_production_form_factor
    return nil unless submission_external&.identifier
    prefix, _track = submission_external.identifier.to_s.split(":", 2)
    GooglePlayStoreIntegration::FORM_FACTOR_TRACKS.key?(prefix) ? prefix : nil
  end

  private

  def set_production_defaults
    self.integrable_id = default_app.id
    self.integrable_type = "App"
    self.submission_external = Config::SubmissionExternal.from_json(default_production_config)
  end

  def default_production_config
    ReleasePlatform::DEFAULT_PROD_RELEASE_CONFIG[platform.to_sym][:submissions][0][:submission_config]
  end

  def default_app
    release_step_config.release_platform_config.release_platform.app
  end

  def apply_form_factor_to_identifier
    return unless submission_external

    submission_external.identifier = if production_form_factor.present?
      "#{production_form_factor}:#{base_production_identifier}"
    else
      base_production_identifier
    end
  end

  def base_production_identifier
    current = submission_external.identifier.to_s
    prefix, track = current.split(":", 2)
    GooglePlayStoreIntegration::FORM_FACTOR_TRACKS.key?(prefix) ? (track.presence || "production") : current
  end
end
