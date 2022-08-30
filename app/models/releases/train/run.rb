class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :was_run_at

  STAMPABLE_REASONS = %w[created status_changed pull_request_not_required pull_request_not_mergeable tag_reference_already_exists]

  belongs_to :train, class_name: "Releases::Train"
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id, dependent: :destroy, inverse_of: :train_run
  has_many :steps, through: :step_runs
  has_many :pull_requests, class_name: "Releases::PullRequest", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run
  has_many :passports, dependent: :destroy

  enum status: {on_track: "on_track", post_release: "post_release", finished: "finished", error: "error"}

  before_create :set_version
  before_update :status_change_stamp!, if: -> { status_changed? }
  after_commit :create_stamp!, on: :create

  scope :pending_release, -> { where(status: [:post_release, :on_track]) }

  delegate :app, to: :train

  def self.pending_release?
    pending_release.exists?
  end

  def committable?
    on_track?
  end

  def next_step
    return train.steps.first if step_runs.empty?
    step_runs.joins(:step).order("step_number").last.step.next
  end

  def running_step?
    step_runs.on_track.exists?
  end

  def release_branch
    branch_name
  end

  def set_version
    self.release_version = train.bump_version!.to_s
  end

  def perform_post_release!
    self.status = Releases::Train::Run.statuses[:post_release]
    save!
    Services::PostRelease.call(self)
  end

  def mark_finished!
    self.status = Releases::Train::Run.statuses[:finished]
    self.completed_at = Time.current
    save!
  end

  def branch_url
    train.vcs_provider&.branch_url(train.app.config&.code_repository_name, branch_name)
  end

  def tag_url
    train.vcs_provider&.tag_url(train.app.config&.code_repository_name, train.tag_name)
  end

  def last_commit
    commits.order(:created_at).last
  end

  def last_run_for(step)
    step_runs.where(step: step).last
  end

  def current_step
    steps.order(:step_number).last&.step_number
  end

  def finished_steps?
    latest_finished_step_runs.size == train.steps.size
  end

  def latest_finished_step_runs
    step_runs
      .where(status: Releases::Step::Run.statuses[:success])
      .order(updated_at: :desc)
  end

  def final_artifact_file
    return unless finished?

    step_runs
      .where(status: Releases::Step::Run.statuses[:success])
      .joins(:step)
      .order(step_number: :desc, updated_at: :desc)
      .first
      &.build_artifact
      &.file
  end

  def signed?
    last_run_for(train.steps.last)&.approval_approved?
  end

  def fully_qualified_branch_name_hack
    [app.config.code_repository_organization_name_hack, ":", branch_name].join
  end

  def event_stamp!(reason:, kind:, data:)
    PassportJob.perform_later(
      id,
      self.class.name,
      reason:,
      kind:,
      message: I18n.t("passport.#{reason}", **data),
      metadata: data
    )
  end

  def create_stamp!
    PassportJob.perform_later(
      id,
      self.class.name,
      reason: :created,
      kind: :success,
      message: I18n.t("passport.stampable.created", stampable: "release", status: status),
      metadata: {status: status}
    )
  end

  def status_change_stamp!
    PassportJob.perform_later(
      id,
      self.class.name,
      reason: :status_changed,
      kind: :success,
      message: I18n.t("passport.stampable.status_changed", stampable: "release", from: status_was, to: status),
      metadata: {from: status_was, to: status}
    )
  end
end
