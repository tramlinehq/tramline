# == Schema Information
#
# Table name: release_platform_configs
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_platform_id :uuid             indexed
#
class Config::ReleasePlatform < ApplicationRecord
  self.table_name = "release_platform_configs"

  belongs_to :release_platform
  has_one :internal_workflow, -> { internal }, class_name: "Config::Workflow", inverse_of: :release_platform_config, dependent: :destroy
  has_one :release_candidate_workflow, -> { release_candidate }, class_name: "Config::Workflow", inverse_of: :release_platform_config, dependent: :destroy
  has_one :internal_release, -> { internal }, class_name: "Config::ReleaseStep", inverse_of: :release_platform_config, dependent: :destroy
  has_one :beta_release, -> { beta }, class_name: "Config::ReleaseStep", inverse_of: :release_platform_config, dependent: :destroy
  has_one :production_release, -> { production }, class_name: "Config::ReleaseStep", inverse_of: :release_platform_config, dependent: :destroy

  accepts_nested_attributes_for :internal_workflow, allow_destroy: true
  accepts_nested_attributes_for :release_candidate_workflow, allow_destroy: true
  accepts_nested_attributes_for :internal_release, allow_destroy: true
  accepts_nested_attributes_for :beta_release, allow_destroy: true
  accepts_nested_attributes_for :production_release, allow_destroy: true

  delegate :platform, to: :release_platform
  attr_accessor :production_release_enabled, :internal_workflow_enabled, :internal_release_enabled, :beta_release_enabled
  after_initialize :set_defaults
  validate :validate_rc_workflow_presence
  validate :validate_workflow_identifiers
  validate :validate_release_steps_presence
  validate :validate_submission_uniqueness

  def self.from_json(json)
    json = json.with_indifferent_access
    release_config = new(json.except("workflows", "internal_release", "beta_release", "production_release", "id"))
    release_config.internal_workflow = Config::Workflow.from_json(json["workflows"]["internal"]) if json.dig("workflows", "internal").present?
    release_config.release_candidate_workflow = Config::Workflow.from_json(json["workflows"]["release_candidate"])
    release_config.internal_release = Config::ReleaseStep.from_json(json["internal_release"].merge("kind" => "internal")) if json["internal_release"]
    release_config.beta_release = Config::ReleaseStep.from_json(json["beta_release"].merge("kind" => "beta")) if json["beta_release"]
    release_config.production_release = Config::ReleaseStep.from_json(json["production_release"].merge("kind" => "production")) if json["production_release"]
    release_config
  end

  def set_defaults
    self.production_release_enabled = production_release.present?
    self.internal_workflow_enabled = internal_workflow.present?
    self.internal_release_enabled = internal_release.present?
    self.beta_release_enabled = beta_release.present?
  end

  def as_json(options = {})
    {
      workflows: {
        internal: internal_workflow.as_json,
        release_candidate: release_candidate_workflow.as_json
      },
      internal_release: internal_release.as_json,
      beta_release: beta_release.as_json,
      production_release: production_release.as_json
    }
  end

  def pick_internal_workflow
    internal_workflow || release_candidate_workflow
  end

  def internal_release?
    internal_release.present?
  end

  def only_beta_release?
    !internal_release?
  end

  def beta_submissions?
    beta_release.submissions.present?
  end

  def auto_start_beta_release?
    separate_rc_workflow? && !beta_submissions?
  end

  def separate_rc_workflow?
    internal_workflow.present?
  end

  def production_release?
    production_release.present?
  end

  # Custom validation to check if release candidate workflow is present
  def validate_rc_workflow_presence
    errors.add(:release_candidate_workflow, :not_present) if release_candidate_workflow.nil?
  end

  # Ensure that at least one of internal release, beta release, or production release is configured
  def validate_release_steps_presence
    if internal_release.nil? && beta_release.nil? && production_release.nil?
      errors.add(:base, :at_least_one_release_step)
    end
  end

  # Validate that multiple workflows have unique identifiers
  def validate_workflow_identifiers
    workflow_identifiers = [internal_workflow&.identifier, release_candidate_workflow&.identifier].compact
    if workflow_identifiers.uniq.length != workflow_identifiers.length
      errors.add(:base, :unique_workflows)
    end
  end

  # Ensure submissions across release steps (internal, beta, production) are unique by type and submission_external identifier
  def validate_submission_uniqueness
    all_submissions = Set.new

    [internal_release, beta_release, production_release].compact.each do |release_step|
      release_step.submissions.each do |submission|
        submission_key = [submission.submission_type, submission.submission_external&.identifier].join("-")

        unless all_submissions.add?(submission_key)
          errors.add(:base, :unique_submissions)
          break
        end
      end
    end
  end
end
