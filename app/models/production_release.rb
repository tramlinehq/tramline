# == Schema Information
#
# Table name: production_releases
#
#  id                      :uuid             not null, primary key
#  config                  :jsonb            not null
#  status                  :string           default("inflight"), not null, indexed => [release_platform_run_id], indexed => [release_platform_run_id], indexed => [release_platform_run_id]
#  tag_name                :string
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
  include Taggable
  include Sanitizable

  belongs_to :release_platform_run
  belongs_to :build
  belongs_to :previous, class_name: "ProductionRelease", inverse_of: :next, optional: true
  has_one :next, class_name: "ProductionRelease", inverse_of: :previous, dependent: :nullify
  has_one :store_submission, as: :parent_release, dependent: :destroy
  has_many :release_health_events, dependent: :destroy, inverse_of: :production_release
  has_many :release_health_metrics, dependent: :destroy, inverse_of: :production_release

  scope :sequential, -> { order(created_at: :desc) }

  delegate :app, :train, :release, :platform, :release_platform, :hotfix?, to: :release_platform_run
  delegate :monitoring_provider, to: :app
  delegate :store_rollout, :prepared_at, to: :store_submission
  delegate :notify!, :notify_with_changelog!, to: :train
  delegate :commit, :version_name, :build_number, to: :build
  delegate :release_health_rules, to: :release_platform

  STAMPABLE_REASONS = %w[created active finished tag_created vcs_release_created]

  STATES = {
    inflight: "inflight",
    active: "active",
    stale: "stale",
    finished: "finished"
  }
  INITIAL_STATE = STATES[:inflight]
  ACTIONABLE_STATES = [STATES[:inflight], STATES[:active]]

  JOB_FREQUENCY = {
    BugsnagIntegration => 5.minutes,
    CrashlyticsIntegration => 120.minutes
  }
  RELEASE_MONITORING_PERIOD_IN_DAYS = {
    BugsnagIntegration => 15,
    CrashlyticsIntegration => 5
  }

  enum :status, STATES

  def tester_notes? = false

  def release_notes? = true

  def version_bump_required?
    return false if release_platform_run.release_version.to_semverish > build.release_version.to_semverish
    return true if finished?
    return true if active?
    return true if store_submission.post_review?
    false
  end

  def failure?
    store_submission.failed?
  end

  def rollout_active?
    store_rollout&.started?
  end

  def mark_as_stale!
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

    ProductionReleases::CreateTagJob.perform_async(id) if tag_name.blank? && !store_rollout.staged_rollout?
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
    notify_with_changelog!("Production release was started!", :production_rollout_started, rollout_started_notification_params)

    ProductionReleases::CreateTagJob.perform_async(id) if tag_name.blank?

    return if beyond_monitoring_period?
    return if monitoring_provider.blank?
    return if app.monitoring_disabled?

    FetchHealthMetricsJob.perform_async(id, JOB_FREQUENCY[monitoring_provider.class])
  end

  def beyond_monitoring_period?
    finished? && completed_at && completed_at < release_monitoring_period
  end

  def fetch_health_data!
    return if store_rollout.blank?
    return if beyond_monitoring_period?
    return if monitoring_provider.blank?
    return if app.monitoring_disabled?
    return if stale?

    release_data = monitoring_provider.find_release(platform, version_name, build_number, store_rollout.created_at)
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

  def check_release_health
    return unless latest_health_data&.fresh?
    latest_health_data.check_release_health
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

  def rollout_started_notification_params
    changes = changes_since_previous
    store_rollout.notification_params.merge(
      diff_changelog: sanitize_commit_messages(changes),
      linked_diff_changelog: ChangelogLinking::Processor.new(train.app).process(
        sanitize_commit_messages(changes)
      )
    )
  end

  def commits_since_previous
    commits_since_last_release = release.release_changelog&.commits || []
    commits_since_last_run = release.all_commits.between_commits(previous&.commit, commit) || []

    if previous
      # if it's a patch-fix, only return the delta of commits
      commits_since_last_run
    else
      # if it's the first rollout, return all the commits in the release
      (commits_since_last_run + commits_since_last_release).uniq { |c| c.commit_hash }
    end
  end

  def changes_since_previous
    commits_since_last_release = release.release_changelog&.commits&.commit_messages(true) || []
    commits_since_last_run = release.all_commits.between_commits(previous&.commit, commit).commit_messages(true) || []

    if previous
      # if it's a patch-fix, only return the delta of changes
      commits_since_last_run
    else
      # if it's the first rollout, return all the changes in the release
      (commits_since_last_run + commits_since_last_release).uniq
    end
  end

  def release_monitoring_period
    RELEASE_MONITORING_PERIOD_IN_DAYS[monitoring_provider.class].days.ago
  end

  private

  def base_tag_name
    tag = "v#{version_name}"
    tag << "-hotfix" if hotfix?
    tag << (train.tag_store_releases_with_platform_names ? "-#{platform}" : "")
    tag
  end

  # either the previous production release tag, or
  # it's the release's previous tag
  def previous_tag_name
    previous&.tag_name.presence || release.previous_tag_name
  end
end
