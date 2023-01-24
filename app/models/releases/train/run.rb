# == Schema Information
#
# Table name: train_runs
#
#  id              :uuid             not null, primary key
#  branch_name     :string           not null
#  code_name       :string           not null
#  commit_sha      :string
#  completed_at    :datetime
#  release_version :string           not null
#  scheduled_at    :datetime         not null
#  status          :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  train_id        :uuid             not null, indexed
#
class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include ActionView::Helpers::DateHelper
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
    "release_branch_created",
    "kickoff_pr_succeeded",
    "version_changed",
    "finalizing",
    "pull_request_not_mergeable",
    "post_release_pr_succeeded",
    "finalize_failed",
    "finished"
  ]

  STATES = {
    created: "created",
    on_track: "on_track",
    post_release: "post_release",
    post_release_started: "post_release_started",
    post_release_failed: "post_release_failed",
    finished: "finished"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      transitions from: [:created, :on_track], to: :on_track
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseJob.perform_later(id) } do
      transitions from: [:on_track, :post_release_failed], to: :post_release_started
    end

    event :fail_post_release_phase do
      transitions from: :post_release_started, to: :post_release_failed
    end

    event :finish, after_commit: :on_finish! do
      before { self.completed_at = Time.current }
      transitions from: :post_release_started, to: :finished
    end
  end

  before_create :set_version
  after_commit -> { create_stamp!(data: {version: release_version}) }, on: :create

  scope :pending_release, -> { where.not(status: :finished) }
  delegate :app, :pre_release_prs?, to: :train

  def tag_name
    "v#{release_version}"
  end

  def overall_movement_status
    all_steps.to_h do |step|
      run = last_commit&.run_for(step)
      [step, run.present? ? run.status_summary : {not_started: true}]
    end
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
    may_start_post_release_phase? && finished_steps? && signed?
  end

  def next_step
    return all_steps.first if step_runs.empty?
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
    commits.last.step_runs.success.size == all_steps.size
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
    last_run_for(all_steps.last)&.approval_approved?
  end

  def events
    step_runs
      .left_joins(:commit, :deployment_runs)
      .pluck("train_step_runs.id, deployment_runs.id, releases_commits.id")
      .flatten
      .uniq
      .compact
      .push(id)
      .then { |ids| Passport.where(stampable_id: ids).order(event_timestamp: :desc) }
  end

  def all_steps
    train.steps
  end

  def on_finish!
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    train.notify!("Release is complete!", :release_ended, finalize_phase_metadata)
  end

  def finalize_phase_metadata
    {
      total_run_time: distance_of_time_in_words(created_at, completed_at),
      release_tag: tag_name,
      release_tag_url: tag_url,
      final_artifact_url: final_build_artifact&.download_url,
      store_url: app.store_link
    }
  end
end
