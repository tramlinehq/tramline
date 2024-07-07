# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :bigint           not null, primary key
#  config                  :jsonb            not null
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_platform_run_id :uuid             not null, indexed
#
class PreProdRelease < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  belongs_to :release_platform_run
  has_one :workflow_run, dependent: :destroy
  has_many :store_submissions, as: :parent_release, dependent: :destroy

  STATES = {
    created: "created",
    failed: "failed",
    finished: "finished"
  }

  enum status: STATES

  def fail!
    update!(status: STATES[:failed])
  end

  def trigger_workflow!(workflow, commit)
    create_workflow_run!(workflow_config: workflow, release_platform_run:, commit:)
  end

  def trigger_submissions!(build)
    first_submission_config = conf.submissions.first
    trigger_submission!(first_submission_config, build)
  end

  def rollout_complete!(submission)
    next_submission_config = conf.submissions.fetch_by_number(submission.sequence_number + 1)
    if next_submission_config
      trigger_submission!(next_submission_config, submission.build)
    else
      finish!(submission.build)
    end
  end

  private

  def trigger_submission!(submission_config, build)
    submission_config.submission_type.create_and_trigger!(self, submission_config, build)
  end

  def conf = ReleaseConfig::Platform.new(config)
end

# start a submission - there needs to be a common start function between submission classes
# wait for its completion - submission_completed! callback from submission
# see if next submission is auto promotable (if undefined, use the top level auto promote config)
# start the next submission and repeat till there are no more submissions
# if there are no more submissions, mark the release as completed and send signal to coordinato
