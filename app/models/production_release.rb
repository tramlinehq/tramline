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

  delegate :app, :train, to: :release_platform_run
  delegate :monitoring_provider, to: :app
  delegate :store_rollout, to: :store_submission
  delegate :notify!, to: :train

  STAMPABLE_REASONS = %w[created active finished]

  STATES = {
    inflight: "inflight",
    active: "active",
    stale: "stale",
    finished: "finished"
  }
  INITIAL_STATE = STATES[:inflight]
  ACTIONABLE_STATES = [STATES[:inflight], STATES[:active]]

  enum status: STATES

  def version_bump_required?
    return false unless release_platform_run.latest_rc_build?(build)
    return true if active?
    return true if store_submission.version_bump_required? && store_submission.finished?
    false
  end

  def mark_as_stale!
    return if finished?
    update!(status: STATES[:stale])
  end

  def rollout_complete!(_)
    with_lock do
      update!(status: STATES[:finished])
      event_stamp!(reason: :finished, kind: :notice, data: stamp_data)
      Signal.production_release_is_complete!(release_platform_run)
    end
  end

  def actionable?
    ACTIONABLE_STATES.include?(status)
  end

  def completed_at
    store_rollout.completed_at if finished?
  end

  def trigger_submission!
    return finish! if conf.submissions.blank?

    submission_config = conf.submissions.first
    submission_config.submission_type.create_and_trigger!(self, submission_config, build)
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
    return if beyond_monitoring_period?
    return if monitoring_provider.blank?

    release_data = monitoring_provider.find_release(platform, build_version, build_number)
    return if release_data.blank?

    release_health_metrics.create!(fetched_at: Time.current, **release_data)
  end

  def conf = ReleaseConfig::Platform::ReleaseStep.new(config)

  def production? = true

  def stamp_data
    {
      build_number: build.build_number,
      version: build.version_name
    }
  end

  def notification_params
    release_platform_run.notification_params.merge(
      build_number: build.build_number,
      release_version: build.version_name
    )
  end
end
