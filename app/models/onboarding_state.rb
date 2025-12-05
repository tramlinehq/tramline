# == Schema Information
#
# Table name: onboarding_states
#
#  id         :bigint           not null, primary key
#  data       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :uuid             not null, indexed
#
class OnboardingState < ApplicationRecord
  belongs_to :app

  store_accessor :data, %i[
    version_strategy
    minor_version_bump_strategy
    patch_version_bump_strategy
    build_version_strategy
    branching_strategy
    branch_naming_format
    source_branch
    release_branch_format
    tagging_enabled
    tag_format
    tag_all_releases
    ci_cd_workflow
    ci_cd_provider
    ci_cd_workflow_path
    ci_cd_branch_pattern
    auto_deployment
    auto_increment_version
    copy_changelog
    rc_submission_enabled
    rc_submission_provider
    rc_submission_config
    production_submission_enabled
    production_submission_provider
    production_submission_config
    completed_steps
  ]

  # Default values
  after_initialize :set_defaults

  def set_defaults
    self.data ||= {}
    self.data[:completed_steps] ||= []
  end

  def complete_step(step)
    completed_steps << step unless completed_steps.include?(step)
    save
  end

  def step_completed?(step)
    completed_steps.include?(step)
  end

  def ready_for_completion?
    # Check if all required steps are completed
    %w[version branching tags workflows submissions].all? { |step| step_completed?(step) }
  end

  def completed_steps
    data[:completed_steps] || []
  end
end
