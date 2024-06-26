# == Schema Information
#
# Table name: production_releases
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class ProductionRelease < ApplicationRecord
  include Coordinatable
  include Loggable

  RELEASE_MONITORING_PERIOD_IN_DAYS = 15

  belongs_to :release_platform_run
  belongs_to :build
  has_one :store_submission, dependent: :destroy
  has_many :release_health_events, dependent: :destroy, inverse_of: :production_release
  has_many :release_health_metrics, dependent: :destroy, inverse_of: :production_release

  delegate :app, to: :release_platform_run
  delegate :store_rollout, to: :store_submission

  def finished?
    store_submission.finished? && store_rollout.finished?
  end

  def completed_at
    store_rollout.completed_at if finished?
  end

  def rollout_started!
    return if beyond_monitoring_period?
    return if monitoring_provider.blank?

    V2::FetchHealthMetricsJob.perform_later(id)
  end

  def rollout_complete!
    Coordinators::Signals.production_release_is_complete!(release_platform_run)
  end

  def fetch_health_data!
    return if beyond_monitoring_period?
    return if monitoring_provider.blank?

    release_data = monitoring_provider.find_release(platform, build_version, build_number)
    return if release_data.blank?

    release_health_metrics.create!(fetched_at: Time.current, **release_data)
  end

  def beyond_monitoring_period?
    finished? && completed_at < RELEASE_MONITORING_PERIOD_IN_DAYS.days.ago
  end

  def monitoring_provider = app.monitoring_provider
end

# TODO:
# add released_at to store_rollout
# add completed_at to production_release
# fix notification for store rollout final thing to be more deployment run end types