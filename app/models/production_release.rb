# == Schema Information
#
# Table name: production_releases
#
#  id                      :bigint           not null, primary key
#  config                  :jsonb            not null
#  status                  :string           default("inflight"), not null, indexed => [release_platform_run_id], indexed => [release_platform_run_id], indexed => [release_platform_run_id]
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  previous_id             :bigint           indexed
#  release_platform_run_id :uuid             not null, indexed, indexed => [status], indexed => [status], indexed => [status]
#
class ProductionRelease < ApplicationRecord
  include Loggable
  RELEASE_MONITORING_PERIOD_IN_DAYS = 15

  belongs_to :release_platform_run
  belongs_to :build
  belongs_to :previous, class_name: "ProductionRelease", inverse_of: :next, optional: true
  has_one :next, class_name: "ProductionRelease", inverse_of: :previous, dependent: :nullify
  has_one :store_submission, as: :parent_release, dependent: :destroy
  has_many :release_health_events, dependent: :destroy, inverse_of: :production_release
  has_many :release_health_metrics, dependent: :destroy, inverse_of: :production_release

  delegate :app, to: :release_platform_run
  delegate :monitoring_provider, to: :app
  delegate :store_rollout, to: :store_submission

  STATES = {
    inflight: "inflight",
    active: "active",
    stale: "stale",
    finished: "finished"
  }
  INITIAL_STATE = STATES[:inflight]

  enum status: STATES

  def mark_as_stale!
    return if finished?
    update!(status: STATES[:stale])
  end

  def rollout_complete!(_)
    with_lock do
      update!(status: STATES[:finished])
      Signal.production_release_is_complete!(release_platform_run)
    end
  end

  def actionable?
    inflight? || active?
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
end

# TODO: [V2]
# fix notification for store rollout final thing to be more deployment run end types