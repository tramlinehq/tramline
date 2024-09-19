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

  accepts_nested_attributes_for :internal_workflow
  accepts_nested_attributes_for :release_candidate_workflow
  accepts_nested_attributes_for :internal_release
  accepts_nested_attributes_for :beta_release
  accepts_nested_attributes_for :production_release

  delegate :platform, to: :release_platform
  attr_accessor :production_release_enabled, :internal_workflow_enabled, :internal_release_enabled, :beta_release_enabled

  after_initialize :set_defaults

  def self.from_json(json)
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
end
