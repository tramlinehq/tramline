# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :bigint           not null, primary key
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
  has_one :build, through: :workflow_run
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

  def trigger_workflow!
    create_workflow_run!(workflow: workflow)
  end

  def trigger_submissions!
    trigger_submission!(release_config[:distributions].first)
  end

  def rollout_complete!(submission)
    if (config = next_submission_config(submission))
      trigger_submission!(config)
    else
      finish!
    end
  end

  def finish!
    update!(status: STATES[:finished])
    Coordinators::Signals.build_is_available_for_regression_testing!(build)
  end

  def build_upload_failed!
    # TODO: Implement this
  end

  private

  def trigger_submission!(config)
    submission = submission_class.create!(
      pre_prod_release: self,
      build:,
      sequence_number: config[:number],
      submission_config: config.slice(:submission_config, :rollout_config)
    )
    submission.trigger! if config[:auto_promote]
  end

  def release_config
    {auto_promote: true,
     distributions: [
       {number: 1,
        submission_type: "PlayStoreSubmission",
        submission_config: {id: :internal, name: "internal testing"},
        rollout_config: [100],
        auto_promote: true},
       {number: 2,
        submission_type: "PlayStoreSubmission",
        submission_config: {id: :alpha, name: "closed testing"},
        rollout_config: [10, 100],
        auto_promote: true}
     ]}
  end

  def next_submission_config(submission)
    next_sequence_number = submission.sequence_number + 1
    release_config[:distributions].find { |dist| dist[:number] == next_sequence_number }
  end

  def submission_config(submission)
    release_config[:distributions].find { |dist| dist[:number] == submission.sequence_number }
  end

  def rollout_needed?(submission)
    submission_config(submission)[:rollout_config].present? && submission.rollout_supported?
  end

  # start a submission - there needs to be a common start function between submission classes
  # wait for its completion - submission_completed! callback from submission
  # see if next submission is auto promotable (if undefined, use the top level auto promote config)
  # start the next submission and repeat till there are no more submissions
  # if there are no more submissions, mark the release as completed and send signal to coordinato
end
