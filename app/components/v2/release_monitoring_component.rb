class V2::ReleaseMonitoringComponent < V2::BaseComponent
  METRICS = [:staged_rollout, :adoption_rate, :adoption_chart, :errors, :stability]
  SIZES = {
    compact: {cols: 2},
    default: {cols: 3},
    max: {cols: 4}
  }

  # TODO: [V2] [post-alpha] Add release health events here
  def initialize(store_rollout:, metrics: METRICS, size: :default, num_events: 3)
    raise ArgumentError, "metrics must be one of #{METRICS}" unless (metrics - METRICS).empty?

    @store_rollout = store_rollout
    @metrics = metrics
    @size = size
    @cols = SIZES[@size][:cols]
    @num_events = num_events
  end

  delegate :adoption_rate, to: :release_data, allow_nil: true
  delegate :monitoring_provider, :platform, to: :parent_release
  delegate :parent_release, :store_submission, :last_rollout_percentage, :provider, to: :store_rollout
  delegate :current_user, to: :helpers
  delegate :store_link, to: :store_submission

  attr_reader :store_rollout, :metrics, :size

  def empty_component?
    release_data.blank?
  end

  def monitoring_provider_url
    monitoring_provider.dashboard_url(platform:, release_id: release_data&.external_release_id)
  end

  def release_data
    @release_data ||= parent_release.latest_health_data
  end

  def staged_rollout_text
    return "Fully Released" unless store_rollout.is_staged_rollout?
    return "Fully Released" if store_rollout.fully_released?
    "Stage #{store_rollout.stage} of #{store_rollout.config.size}"
  end

  def user_stability
    value = release_data.user_stability.blank? ? "-" : "#{release_data.user_stability}%"
    metric_data("user_stability", value)
  end

  def session_stability
    value = release_data.session_stability.blank? ? "-" : "#{release_data.session_stability}%"
    metric_data("session_stability", value)
  end

  def errors_count
    metric_data("errors_count", release_data.errors_count)
  end

  def new_errors_count
    metric_data("new_errors_count", release_data.new_errors_count)
  end

  def adoption_chart_data
    return unless release_data
    range_end = release_data.fetched_at
    range_start = store_rollout.created_at
    @chart_data ||= parent_release
      .release_health_metrics
      .group_by_day(:fetched_at, range: range_start..range_end)
      .maximum("round(CAST(sessions_in_last_day::float * 100 / total_sessions_in_last_day::float as numeric), 2)")
      .compact
      .map { |k, v| [k.strftime("%d %b"), {adoption_rate: v, rollout_percentage: store_rollout.rollout_percentage_at(k)}] }
      .last(10)
      .to_h

    return unless @chart_data.keys.size >= 2

    {
      data: @chart_data,
      type: "line",
      value_format: "number",
      name: "release_health.adoption_rate"
    }
  end

  def grid_cols
    "grid-cols-#{@cols}"
  end

  def full_span
    "col-span-#{@cols}"
  end

  private

  def metric_data(metric_name, value)
    {
      value:,
      is_healthy: release_data.metric_healthy?(metric_name),
      rules: release_data.rules_for_metric(metric_name)
    }
  end
end
