# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                         :bigint           not null, primary key
#  config                     :jsonb            not null
#  status                     :string           default("created"), not null
#  tester_notes               :text
#  type                       :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  commit_id                  :uuid             indexed
#  parent_internal_release_id :bigint           indexed
#  previous_id                :bigint           indexed
#  release_platform_run_id    :uuid             not null, indexed
#
class PreProdRelease < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  belongs_to :release_platform_run
  belongs_to :previous, class_name: "PreProdRelease", inverse_of: :next, optional: true
  belongs_to :commit
  has_one :next, class_name: "PreProdRelease", inverse_of: :previous, dependent: :nullify
  has_one :triggered_workflow_run, class_name: "WorkflowRun", dependent: :destroy, inverse_of: :triggering_release
  has_many :store_submissions, as: :parent_release, dependent: :destroy

  scope :inactive, -> { where(status: INACTIVE) }

  before_create :set_default_tester_notes
  after_create_commit -> { previous&.mark_as_stale! }

  delegate :release, :train, to: :release_platform_run

  STATES = {
    created: "created",
    failed: "failed",
    stale: "stale",
    finished: "finished"
  }
  INACTIVE = STATES.values - ["created"]

  enum status: STATES

  def mark_as_stale!
    with_lock do
      return if finished?
      update!(status: STATES[:stale])
    end
  end

  def fail!
    update!(status: STATES[:failed])
  end

  def actionable? = created?

  def workflow_run
    triggered_workflow_run || parent_internal_release&.workflow_run
  end

  def build
    workflow_run&.build
  end

  def production? = false

  def trigger_submissions!
    return unless actionable?
    return finish! if conf.submissions.blank?
    trigger_submission!(conf.submissions.first)
  end

  def rollout_started!
    # do something here, do we need to?
  end

  def rollout_complete!(submission)
    next_submission_config = conf.submissions.fetch_by_number(submission.sequence_number + 1)
    if next_submission_config
      trigger_submission!(next_submission_config)
    else
      finish!
    end
  end

  def conf = ReleaseConfig::Platform::ReleaseStep.new(config)

  def commits_since_previous
    changes_since_last_release = release.release_changelog&.normalized_commits
    last_successful_run = previous_successful
    changes_since_last_run = release.all_commits.between_commits(last_successful_run&.commit, commit)

    return changes_since_last_run if last_successful_run.present?

    return (changes_since_last_release || []) if previous.blank?
    ((changes_since_last_run || []) + (changes_since_last_release || [])).uniq { |c| c.commit_hash }
  end

  def changes_since_previous
    changes_since_last_release = release.release_changelog&.commit_messages(true)
    last_successful_run = previous_successful
    changes_since_last_run = release
      .all_commits
      .between_commits(last_successful_run&.commit, commit)
      &.commit_messages(true)

    return changes_since_last_run if last_successful_run.present?
    return (changes_since_last_release || []) if previous.blank?
    ((changes_since_last_run || []) + (changes_since_last_release || [])).uniq
  end

  # NOTES: This logic should simplify once we allow users to edit the tester notes
  def set_default_tester_notes
    self.tester_notes = changes_since_previous
      .map { |str| str&.strip }
      .flat_map { |line| train.compact_build_notes? ? line.split("\n").first : line.split("\n") }
      .map { |line| line.gsub(/\p{Emoji_Presentation}\s*/, "") }
      .map { |line| line.gsub(/"/, "\\\"") }
      .reject { |line| line =~ /\AMerge|\ACo-authored-by|\A---------/ }
      .compact_blank
      .uniq
      .map { |str| "• #{str}" }
      .join("\n").presence || "Nothing new"
  end

  def previous_successful
    return if previous.blank?
    return previous if previous.finished?
    previous.previous_successful
  end

  def new_build_available? = false

  def carried_over? = false

  def new_commit_available? = false

  private

  def trigger_submission!(submission_config)
    submission_config.submission_type.create_and_trigger!(self, submission_config, build)
  end
end

# start a submission - there needs to be a common start function between submission classes
# wait for its completion - submission_completed! callback from submission
# see if next submission is auto promotable (if undefined, use the top level auto promote config)
# start the next submission and repeat till there are no more submissions
# if there are no more submissions, mark the release as completed and send signal to coordinato
