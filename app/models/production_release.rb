# == Schema Information
#
# Table name: production_releases
#
#  id                      :uuid             not null, primary key
#  config                  :jsonb            not null
#  status                  :string           default("inflight"), not null, indexed => [release_platform_run_id], indexed => [release_platform_run_id], indexed => [release_platform_run_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  previous_id             :uuid             indexed
#  release_platform_run_id :uuid             not null, indexed, indexed => [status], indexed => [status], indexed => [status]
#
class ProductionRelease < ApplicationRecord
  using RefinedString
  has_paper_trail
  # include Sandboxable
  include Loggable
  include Passportable
  RELEASE_MONITORING_PERIOD_IN_DAYS = 15

  belongs_to :release_platform_run
  belongs_to :build
  belongs_to :previous, class_name: "ProductionRelease", inverse_of: :next, optional: true
  has_one :next, class_name: "ProductionRelease", inverse_of: :previous, dependent: :nullify
  has_one :store_submission, as: :parent_release, dependent: :destroy
  has_many :release_health_events, dependent: :destroy, inverse_of: :production_release
  has_many :release_health_metrics, dependent: :destroy, inverse_of: :production_release

  scope :sequential, -> { order(created_at: :desc) }

  delegate :app, :train, :release, :platform, :release_platform, to: :release_platform_run
  delegate :monitoring_provider, to: :app
  delegate :store_rollout, to: :store_submission
  delegate :notify!, to: :train
  delegate :commit, :version_name, :build_number, to: :build
  delegate :release_health_rules, to: :release_platform

  STAMPABLE_REASONS = %w[created active finished]

  STATES = {
    inflight: "inflight",
    active: "active",
    stale: "stale",
    finished: "finished"
  }
  INITIAL_STATE = STATES[:inflight]
  ACTIONABLE_STATES = [STATES[:inflight], STATES[:active]]

  enum :status, STATES

  def tester_notes? = false

  def release_notes? = true

  def version_bump_required?
    return false if release_platform_run.release_version.to_semverish > build.version_name.to_semverish
    return true if finished?
    return true if active?
    return true if store_submission.post_review?
    false
  end

  def mark_as_stale!
    return if finished?
    update!(status: STATES[:stale])
  end

  def rollout_percentage
    store_rollout&.last_rollout_percentage
  end

  def rollout_complete!(_)
    with_lock do
      update!(status: STATES[:finished])
      event_stamp!(reason: :finished, kind: :notice, data: stamp_data)
      notify!("Production release was finished!", :production_release_finished, notification_params)
    end
    Signal.production_release_is_complete!(release_platform_run)
  end

  def actionable?
    return false if release.blocked_for_production_release?
    ACTIONABLE_STATES.include?(status) && release_platform_run.on_track?
  end

  def completed_at
    store_rollout.completed_at if finished?
  end

  def trigger_submission!
    return rollout_complete!(nil) if conf.submissions.blank?

    submission_config = conf.submissions.first
    submission_config.submission_class.create_and_trigger!(self, submission_config, build)
  end

  def rollout_started!
    return unless inflight?
    previous&.mark_as_stale!
    update!(status: STATES[:active])
    notify!("Production release was started!", :production_rollout_started, store_rollout.notification_params)

    return if beyond_monitoring_period?
    return if monitoring_provider.blank?
    V2::FetchHealthMetricsJob.perform_later(id)
  end

  def beyond_monitoring_period?
    finished? && completed_at < RELEASE_MONITORING_PERIOD_IN_DAYS.days.ago
  end

  def fetch_health_data!
    return if store_rollout.blank?
    return if beyond_monitoring_period?
    return if monitoring_provider.blank?

    release_data = monitoring_provider.find_release(platform, version_name, build_number)

    return if release_data.blank?

    release_health_metrics.create!(fetched_at: Time.current, **release_data)
  end

  def latest_health_data
    release_health_metrics.order(fetched_at: :desc).first
  end

  def unhealthy?
    !healthy?
  end

  def healthy?
    return true if release_health_rules.blank?
    return true if release_health_events.blank?

    release_health_rules.all? do |rule|
      event = release_health_events.where(release_health_rule: rule).last
      event.blank? || event.healthy?
    end
  end

  def show_health?
    return true if latest_health_data&.fresh?
    false
  end

  def conf = Config::ReleaseStep.from_json(config)

  def production? = true

  def stamp_data
    {
      build_number: build_number,
      version: version_name
    }
  end

  def notification_params
    release_platform_run.notification_params.merge(
      commit_sha: commit.short_sha,
      commit_url: commit.url,
      build_number: build_number,
      release_version: version_name
    )
  end

  def commits_since_previous
    changes_since_last_release = release.release_changelog&.normalized_commits || []
    changes_since_last_run = release.all_commits.between_commits(previous&.commit, commit) || []

    if previous
      changes_since_last_run
    else
      changes_since_last_release
    end
  end
end
