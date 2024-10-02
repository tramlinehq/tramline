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
  FULL_ROLLOUT_VALUE = BigDecimal("100")

  belongs_to :release_step_config, class_name: "Config::ReleaseStep"
  has_one :submission_external, class_name: "Config::SubmissionExternal", inverse_of: :submission_config, dependent: :destroy

  accepts_nested_attributes_for :submission_external, allow_destroy: true

  validates :submission_type, presence: true
  validate :correct_rollout_stages, if: :rolloutable?

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

  def rolloutable?
    rollout_enabled? && submission_type.in?(%w[PlayStoreSubmission])
  end
end
