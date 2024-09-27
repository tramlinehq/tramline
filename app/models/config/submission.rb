# == Schema Information
#
# Table name: submission_configs
#
#  id                     :bigint           not null, primary key
#  auto_promote           :boolean          default(FALSE)
#  number                 :integer          indexed, indexed => [release_step_config_id]
#  rollout_enabled        :boolean          default(FALSE)
#  rollout_stages         :decimal(8, 5)    default([]), is an Array
#  submission_type        :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  release_step_config_id :bigint           indexed, indexed => [number]
#
class Config::Submission < ApplicationRecord
  self.table_name = "submission_configs"

  belongs_to :release_step_config, class_name: "Config::ReleaseStep"
  has_one :submission_external, class_name: "Config::SubmissionExternal", inverse_of: :submission_config, dependent: :destroy, autosave: true

  accepts_nested_attributes_for :submission_external, allow_destroy: true

  validates :submission_type, presence: true

  def as_json(options = {})
    {
      submission_type: submission_type,
      number: number,
      auto_promote: auto_promote,
      submission_config: submission_external.as_json,
      rollout_config: {
        enabled: rollout_enabled,
        stages: rollout_stages
      }
    }
  end

  def submission_class
    submission_type.constantize
  end

  def next
    release_step_config.submissions.where("number > ?", number).order(:number).first
  end

  def self.from_json(json)
    submission = new(json.except("id", "release_step_config_id", "rollout_config", "submission_config"))
    submission.submission_external = Config::SubmissionExternal.from_json(json["submission_config"])
    submission.rollout_stages = json.dig("rollout_config", "stages")
    submission.rollout_enabled = json.dig("rollout_config", "enabled")
    submission
  end

  def display
    submission_type.classify.constantize.model_name.human
  end
end
