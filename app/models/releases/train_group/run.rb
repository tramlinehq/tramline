# == Schema Information
#
# Table name: train_group_runs
#
#  id                       :uuid             not null, primary key
#  branch_name              :string           not null
#  completed_at             :datetime
#  finished_at              :datetime
#  original_release_version :string
#  release_version          :string
#  scheduled_at             :datetime
#  status                   :string           not null
#  stopped_at               :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  train_group_id           :uuid             not null, indexed
#
class Releases::TrainGroup::Run < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include ActionView::Helpers::DateHelper
  using RefinedString

  self.implicit_order_column = :scheduled_at

  belongs_to :train_group, class_name: "Releases::TrainGroup"
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_group_run_id", dependent: :destroy, inverse_of: :train_group_run
  has_one :release_metadata, class_name: "ReleaseMetadata", foreign_key: "train_group_run_id", dependent: :destroy, inverse_of: :train_group_run
  has_many :train_runs, class_name: "Releases::Train::Run", foreign_key: "train_group_run_id", dependent: :destroy, inverse_of: :train_group_run
  has_many :pull_requests, class_name: "Releases::PullRequest", foreign_key: "train_group_run_id", dependent: :destroy, inverse_of: :train_group_run

  scope :pending_release, -> { where.not(status: [:finished, :stopped]) }

  alias_method :train, :train_group

  STATES = {
    created: "created",
    on_track: "on_track",
    post_release: "post_release",
    post_release_started: "post_release_started",
    post_release_failed: "post_release_failed",
    stopped: "stopped",
    finished: "finished"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      transitions from: [:created, :on_track], to: :on_track
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseGroupJob.perform_later(id) } do
      transitions from: [:on_track, :post_release_failed], to: :post_release_started, guard: :ready_to_be_finalized?
    end

    event :fail_post_release_phase do
      transitions from: :post_release_started, to: :post_release_failed
    end

    event :stop do
      before { self.stopped_at = Time.current }
      after { stop_runs }
      transitions to: :stopped
    end

    event :finish do
      before { self.completed_at = Time.current }
      transitions from: :post_release_started, to: :finished
    end
  end

  before_create :set_version
  after_create :set_default_release_metadata
  after_create :create_train_runs
  after_commit -> { Releases::PreReleaseGroupJob.perform_later(id) }, on: :create
  after_commit -> { Releases::FetchGroupCommitLogJob.perform_later(id) }, on: :create

  attr_accessor :has_major_bump

  delegate :app, :pre_release_prs?, :vcs_provider, to: :train_group
  delegate :cache, to: Rails

  def self.pending_release?
    pending_release.exists?
  end

  def committable?
    created? || on_track?
  end

  def create_train_runs
    train_runs.create!(
      code_name: "dummy",
      scheduled_at:,
      branch_name:,
      release_version:,
      has_major_bump:,
      train: train_group.ios_train
    )
    train_runs.create!(
      code_name: "dummy",
      scheduled_at:,
      branch_name:,
      release_version:,
      has_major_bump:,
      train: train_group.android_train
    )
  end

  def ios_run
    train_runs.where(train: train_group.ios_train).first
  end

  def android_run
    train_runs.where(train: train_group.android_train).first
  end

  def stop_runs
    ios_run&.stop!
    android_run&.stop!
  end

  def set_version
    new_version = train_group.bump_release!(has_major_bump)
    self.release_version = new_version
    self.original_release_version = new_version
  end

  def set_default_release_metadata
    create_release_metadata!(locale: ReleaseMetadata::DEFAULT_LOCALE, release_notes: ReleaseMetadata::DEFAULT_RELEASE_NOTES)
  end

  def fetch_commit_log
    if previous_release.present?
      cache.fetch("app/#{app.id}/train/#{train_group.id}/release_groups/#{id}/commit_log", expires_in: 30.days) do
        vcs_provider.commit_log(previous_release.tag_name, train_group.working_branch)
      end
    end
  end

  def previous_release
    train_group.runs.where(status: "finished").order(completed_at: :desc).first
  end

  def tag_name
    "v#{release_version}"
  end

  def hotfix?
    return false unless on_track?
    release_version.to_semverish > original_release_version.to_semverish
  end

  def stoppable?
    created? || on_track?
  end

  def release_branch
    branch_name
  end

  def branch_url
    train_group.vcs_provider&.branch_url(train_group.app.config&.code_repository_name, branch_name)
  end

  def tag_url
    train_group.vcs_provider&.tag_url(train_group.app.config&.code_repository_name, tag_name)
  end

  def metadata_editable?
    train_runs.any?(&:metadata_editable?)
  end

  class PreReleaseUnfinishedError < StandardError; end

  def close_pre_release_prs
    return if pull_requests.pre_release.blank?

    pull_requests.pre_release.each do |pr|
      created_pr = train_group.vcs_provider.get_pr(pr.number)

      if created_pr[:state].in? %w[open opened]
        raise PreReleaseUnfinishedError, "Pre-release pull request is not merged yet."
      else
        pr.close!
      end
    end
  end

  def version_bump_required?
    ios_run.version_bump_required? || android_run.version_bump_required?
  end

  def ready_to_be_finalized?
    train_runs.all?(&:finished?)
  end

  def finalize_phase_metadata
    {
      total_run_time: distance_of_time_in_words(created_at, completed_at),
      release_tag: tag_name,
      release_tag_url: tag_url,
      store_url: app.store_link
    }
  end
end
