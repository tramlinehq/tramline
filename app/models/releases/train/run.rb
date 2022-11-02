# == Schema Information
#
# Table name: train_runs
#
#  id              :uuid             not null, primary key
#  train_id        :uuid             not null
#  code_name       :string           not null
#  scheduled_at    :datetime         not null
#  commit_sha      :string
#  status          :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  branch_name     :string           not null
#  release_version :string           not null
#  completed_at    :datetime
#
class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  self.implicit_order_column = :scheduled_at

  belongs_to :train, class_name: "Releases::Train"
  has_many :pull_requests, class_name: "Releases::PullRequest", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id, dependent: :destroy, inverse_of: :train_run
  has_many :deployment_runs, through: :step_runs
  has_many :steps, through: :step_runs
  has_many :passports, as: :stampable, dependent: :destroy

  STAMPABLE_REASONS = [
    "created",
    "status_changed",
    "pull_request_not_required",
    "pull_request_not_mergeable",
    "tag_reference_already_exists",
    "tagged_release_already_exists"
  ]

  STATES = {
    created: "created",
    on_track: "on_track",
    post_release: "post_release",
    finished: "finished",
    error: "error"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      transitions from: [:created, :on_track], to: :on_track
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseJob.perform_later(id) } do
      transitions from: :on_track, to: :post_release, guard: :finalizable?
    end

    event :finish do
      before { self.completed_at = Time.current }
      transitions from: :post_release, to: :finished
    end
  end

  before_create :set_version
  after_commit -> { create_stamp!(data: {version: release_version}) }, on: :create
  after_commit :status_update_stamp!, if: -> { saved_change_to_attribute?(:status) }, on: :update

  scope :pending_release, -> { where(status: [:release_phase, :post_release, :on_track, :created]) }
  delegate :app, :pre_release_prs?, to: :train

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
    created? || on_track?
  end

  def stoppable?
    created? || on_track?
  end

  def finalizable?
    (on_track? || post_release?) && signed? && finished_steps?
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
    commits.last.step_runs.success.size == train.steps.size
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

  def events
    types = %w[Releases::Train::Run Releases::Step::Run Releases::Commit DeploymentRun]
    ids = [id, commits.pluck(:id), step_runs.pluck(:id), deployment_runs.pluck(:id)].flatten

    Passport.where(stampable_type: types, stampable_id: ids).order(created_at: :desc)
  end
end
