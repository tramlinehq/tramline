# == Schema Information
#
# Table name: production_releases
#
#  id                      :bigint           not null, primary key
#  config                  :jsonb            not null
#  status                  :string           default("created"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  previous_id             :bigint           indexed
#  release_platform_run_id :uuid             not null, indexed
#
class ProductionRelease < ApplicationRecord
  include Loggable
  include Coordinatable
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

  after_create_commit -> { previous&.mark_as_stale! }

  STATES = {
    created: "created",
    stale: "stale",
    finished: "finished"
  }

  enum status: STATES

  def active? = created?

  def completed_at
    store_rollout.completed_at if finished?
  end

  def rollout_started!
    return if beyond_monitoring_period?
    return if monitoring_provider.blank?

    V2::FetchHealthMetricsJob.perform_later(id)
  end

  def mark_as_stale!
    with_lock do
      return if finished?
      update!(status: STATES[:stale])
    end
  end

  def rollout_complete!(_)
    with_lock do
      update!(status: STATES[:finished])
      Coordinators::Signals.production_release_is_complete!(release_platform_run)
    end
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

# TODO:
# fix notification for store rollout final thing to be more deployment run end types
