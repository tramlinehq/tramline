# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                         :uuid             not null, primary key
#  config                     :jsonb            not null
#  status                     :string           default("created"), not null
#  tester_notes               :text
#  type                       :string           not null, indexed => [release_platform_run_id, commit_id]
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  commit_id                  :uuid             not null, indexed => [release_platform_run_id, type], indexed
#  parent_internal_release_id :uuid             indexed
#  previous_id                :uuid             indexed
#  release_platform_run_id    :uuid             not null, indexed => [commit_id, type], indexed
#
class PreProdRelease < ApplicationRecord
  has_paper_trail
  include AASM
  include Loggable
  include Displayable
  include Passportable

  belongs_to :release_platform_run
  belongs_to :previous, class_name: "PreProdRelease", inverse_of: :next, optional: true
  belongs_to :commit
  has_one :next, class_name: "PreProdRelease", inverse_of: :previous, dependent: :nullify
  has_one :triggered_workflow_run, class_name: "WorkflowRun", dependent: :destroy, inverse_of: :triggering_release
  has_many :store_submissions, -> { sequential }, as: :parent_release, dependent: :destroy, inverse_of: :parent_release

  scope :inactive, -> { where(status: INACTIVE) }

  before_create :set_default_tester_notes

  # TODO: Remove this accessor, once the migration is complete
  attr_accessor :in_data_migration_mode

  after_create_commit -> { previous&.mark_as_stale! }, unless: :in_data_migration_mode
  after_create_commit -> { create_stamp!(data: stamp_data) }, unless: :in_data_migration_mode

  delegate :release, :train, :platform, to: :release_platform_run
  delegate :notify!, :notify_with_snippet!, to: :train

  alias_method :workflow_run, :triggered_workflow_run

  STATES = {
    created: "created",
    failed: "failed",
    stale: "stale",
    finished: "finished"
  }
  INACTIVE = STATES.values - ["created"]

  enum :status, STATES

  def mark_as_stale!
    with_lock do
      return if finished?
      update!(status: STATES[:stale])
    end
  end

  def fail!
    update!(status: STATES[:failed])
  end

  def actionable?
    created? && release_platform_run.on_track?
  end

  def build
    workflow_run&.build
  end

  def production? = false

  def trigger_submissions!
    return unless actionable?
    return finish! if conf.submissions.blank?
    trigger_submission!(conf.first_submission)
  end

  def rollout_started!
    # do something here, do we need to?
  end

  def rollout_complete!(submission)
    return unless actionable?

    next_submission_config = conf.fetch_submission_by_number(submission.sequence_number + 1)
    if next_submission_config
      trigger_submission!(next_submission_config)
    else
      finish!
    end
  end

  def conf = Config::ReleaseStep.from_json(config)

  def commits_since_previous
    changes_since_last_release = release.release_changelog&.normalized_commits
    last_successful_run = previous_successful
    changes_since_last_run = release.all_commits.between_commits(last_successful_run&.commit, commit)

    return changes_since_last_run if last_successful_run.present?
    ((changes_since_last_run || []) + (changes_since_last_release || [])).uniq { |c| c.commit_hash }
  end

  def changes_since_previous
    changes_since_last_release = release.release_changelog&.commit_messages(true)
    last_successful_run = previous_successful
    changes_since_last_run = release
      .all_commits
      .between_commits(last_successful_run&.commit, commit)
      &.commit_messages(true)

    return changes_since_last_run || [] if last_successful_run.present?
    ((changes_since_last_run || []) + (changes_since_last_release || [])).uniq
  end

  # NOTES: This logic should simplify once we allow users to edit the tester notes
  def set_default_tester_notes
    self.tester_notes = changes_since_previous
      .map { |str| str&.strip }
      .flat_map { |line| train.compact_build_notes? ? line.split("\n").first : line.split("\n") }
      .map { |line| line.gsub(/\p{Emoji_Presentation}\s*/, "") }
      .map { |line| line.gsub('"', "\\\"") }
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

  def new_commit_available? = false

  def stamp_data
    {
      commit_sha: commit.short_sha,
      commit_url: commit.url
    }
  end

  def notification_params
    release_platform_run.notification_params.merge(
      commit_sha: commit.short_sha,
      commit_url: commit.url,
      build_number: build.build_number,
      release_version: release.release_version,
      submission_channels: store_submissions.map { |s| "#{s.provider.display} - #{s.submission_channel.name}" }.join(", ")
    )
  end

  private

  def trigger_submission!(submission_config)
    submission_config.submission_class.create_and_trigger!(self, submission_config, build)
  end
end
