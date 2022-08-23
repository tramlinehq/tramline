class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :was_run_at

  STAMPABLE_REASONS = %w[created status_changed]

  belongs_to :train, class_name: "Releases::Train"
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id, dependent: :destroy, inverse_of: :train_run
  has_many :steps, through: :step_runs
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run

  enum status: {on_track: "on_track", error: "error", finished: "finished"}

  before_create :set_version
  before_update :status_change_stamp!, if: -> { status_changed? }
  after_create :create_stamp!

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
    Services::PostRelease.call(self)
  end

  def branch_url
    train.app.vcs_provider&.branch_url(train.app.config&.code_repository_name, branch_name)
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
    step_runs.select("DISTINCT ON (train_step_id) *")
      .where(status: Releases::Step::Run.statuses[:success])
      .order(:train_step_id, updated_at: :desc)
  end

  def signed?
    last_run_for(train.steps.last)&.approval_approved?
  end

  def create_stamp!
    PassportJob.perform_later(
      id,
      self.class.name,
      reason: :created,
      kind: :success,
      message: I18n.t("passport.stampable_created", stampable: "release", status: status),
      metadata: {status: status}
    )
  end

  def status_change_stamp!
    PassportJob.perform_later(
      id,
      self.class.name,
      reason: :status_changed,
      kind: :success,
      message: I18n.t("passport.stampable_status_changed", stampable: "release", from: status_was, to: status),
      metadata: {from: status_was, to: status}
    )
  end
end
