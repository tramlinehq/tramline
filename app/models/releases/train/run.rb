class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  include AASM
  self.implicit_order_column = :was_run_at

  STAMPABLE_REASONS = %w[created status_changed pull_request_not_required pull_request_not_mergeable tag_reference_already_exists]

  belongs_to :train, class_name: "Releases::Train"
  has_many :pull_requests, class_name: "Releases::PullRequest", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id, dependent: :destroy, inverse_of: :train_run
  has_many :steps, through: :step_runs
  has_many :passports, as: :stampable, dependent: :destroy

  STATES = {
    on_track: "on_track",
    release_phase: "release_phase",
    post_release: "post_release",
    finished: "finished",
    error: "error"
  }

  enum status: STATES

  aasm column: :status, requires_lock: true, requires_new_transaction: false, enum: true, create_scopes: false do
    state :on_track, initial: true
    state(*STATES.keys)

    event :start_release_phase do
      transitions from: :on_track, to: :release_phase
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseJob.perform_later(id) } do
      transitions from: :release_phase, to: :post_release, guard: :finalizable?
    end

    event :finish do
      before { self.completed_at = Time.current }
      transitions from: :post_release, to: :finished
    end
  end

  before_create :set_version
  before_update :status_change_stamp!, if: -> { status_changed? }
  after_commit :create_stamp!, on: :create

  scope :pending_release, -> { where(status: [:release_phase, :post_release, :on_track]) }

  delegate :app, to: :train

  def tag_name
    "v#{release_version}"
  end

  def startable_step?(step)
    return false if train.inactive?
    return false unless on_track?
    return true if step.first? && step_runs_for(step).empty?
    return false if step.first?

    (next_step == step) && previous_step_run_for(step).approval_approved? && previous_step_run_for(step).success?
  end

  def step_runs_for(step)
    step_runs.where(step:)
  end

  def previous_step_run_for(step)
    last_run_for(step.previous)
  end

  def self.pending_release?
    pending_release.exists?
  end

  def committable?
    on_track?
  end

  def finalizable?
    (release_phase? || post_release?) && signed? && finished_steps?
  end

  def active_step_run
    step_runs.active.last
  end

  def next_step
    return train.steps.first if step_runs.empty?
    step_runs.joins(:step).order(:step_number).last.step.next
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

  def branch_url
    train.vcs_provider&.branch_url(train.app.config&.code_repository_name, branch_name)
  end

  def tag_url
    train.vcs_provider&.tag_url(train.app.config&.code_repository_name, tag_name)
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
      .select("DISTINCT ON (train_step_id) *")
      .where(status: Releases::Step::Run.statuses[:success])
      .order(:train_step_id, created_at: :desc)
  end

  def last_good_step_run
    step_runs
      .where(status: Releases::Step::Run.statuses[:success])
      .joins(:step)
      .order(step_number: :desc, updated_at: :desc)
      .first
  end

  def final_build_artifact
    return unless finished?
    last_good_step_run&.build_artifact
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
